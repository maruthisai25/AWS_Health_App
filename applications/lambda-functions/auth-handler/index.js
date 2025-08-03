/**
 * AWS Education Platform - Authentication Handler
 * 
 * This Lambda function handles authentication operations for the education platform:
 * - User login (username/password authentication)
 * - User registration (sign up new users)
 * - Email verification (confirm verification codes)
 * - Token refresh (refresh JWT tokens)
 * 
 * The function integrates with AWS Cognito User Pools for user management
 * and provides a unified API for all authentication operations.
 */

const AWS = require('aws-sdk');
const Joi = require('joi');

// Validate required environment variables
if (!process.env.USER_POOL_ID || !process.env.USER_POOL_CLIENT_ID) {
    throw new Error('Missing required environment variables: USER_POOL_ID, USER_POOL_CLIENT_ID');
}

// Initialize AWS services
const cognito = new AWS.CognitoIdentityServiceProvider({
    region: process.env.REGION
});

// Environment variables
const USER_POOL_ID = process.env.USER_POOL_ID;
const USER_POOL_CLIENT_ID = process.env.USER_POOL_CLIENT_ID;
const ENVIRONMENT = process.env.ENVIRONMENT;

// Validation schemas
const loginSchema = Joi.object({
    username: Joi.string().email().required(),
    password: Joi.string().min(8).required()
});

const registerSchema = Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().min(8).required(),
    student_id: Joi.string().min(5).max(20).optional(),
    department: Joi.string().min(2).max(50).optional(),
    role: Joi.string().valid('student', 'teacher', 'admin').required()
});

const verifySchema = Joi.object({
    username: Joi.string().email().required(),
    confirmationCode: Joi.string().length(6).required()
});

const refreshSchema = Joi.object({
    refreshToken: Joi.string().required()
});

/**
 * Main Lambda handler function
 */
exports.handler = async (event) => {
    console.log('Auth Handler Event:', JSON.stringify(event, null, 2));

    // CORS headers
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    };

    try {
        // Handle preflight requests
        if (event.httpMethod === 'OPTIONS') {
            return {
                statusCode: 200,
                headers,
                body: JSON.stringify({ message: 'CORS preflight successful' })
            };
        }

        // Parse request body
        let body;
        try {
            body = JSON.parse(event.body || '{}');
        } catch (error) {
            return createErrorResponse(400, 'Invalid JSON in request body', headers);
        }

        // Route based on path
        const path = event.path;
        const method = event.httpMethod;

        console.log(`Processing ${method} ${path}`);

        switch (path) {
            case '/auth/login':
                if (method === 'POST') {
                    return await handleLogin(body, headers);
                }
                break;
            case '/auth/register':
                if (method === 'POST') {
                    return await handleRegister(body, headers);
                }
                break;
            case '/auth/verify':
                if (method === 'POST') {
                    return await handleVerify(body, headers);
                }
                break;
            case '/auth/refresh':
                if (method === 'POST') {
                    return await handleRefresh(body, headers, event.requestContext.authorizer);
                }
                break;
            default:
                return createErrorResponse(404, 'Endpoint not found', headers);
        }

        return createErrorResponse(405, 'Method not allowed', headers);

    } catch (error) {
        console.error('Unhandled error:', error);
        return createErrorResponse(500, 'Internal server error', headers);
    }
};

/**
 * Handle user login
 */
async function handleLogin(body, headers) {
    try {
        // Validate input
        const { error, value } = loginSchema.validate(body);
        if (error) {
            return createErrorResponse(400, `Validation error: ${error.details[0].message}`, headers);
        }

        const { username, password } = value;

        console.log(`Login attempt for user: ${username}`);

        // Authenticate user with Cognito
        const authParams = {
            AuthFlow: 'USER_PASSWORD_AUTH',
            ClientId: USER_POOL_CLIENT_ID,
            AuthParameters: {
                USERNAME: username,
                PASSWORD: password
            }
        };

        const authResult = await cognito.initiateAuth(authParams).promise();

        // Handle different authentication states
        if (authResult.ChallengeName) {
            return {
                statusCode: 200,
                headers,
                body: JSON.stringify({
                    success: false,
                    challengeName: authResult.ChallengeName,
                    session: authResult.Session,
                    challengeParameters: authResult.ChallengeParameters,
                    message: 'Authentication challenge required'
                })
            };
        }

        // Get user information
        const userInfo = await getUserInfo(username);

        // Successful authentication
        const response = {
            success: true,
            message: 'Login successful',
            tokens: {
                accessToken: authResult.AuthenticationResult.AccessToken,
                idToken: authResult.AuthenticationResult.IdToken,
                refreshToken: authResult.AuthenticationResult.RefreshToken,
                expiresIn: authResult.AuthenticationResult.ExpiresIn
            },
            user: userInfo
        };

        console.log(`Login successful for user: ${username}`);

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify(response)
        };

    } catch (error) {
        console.error('Login error:', error);

        // Handle specific Cognito errors
        if (error.code === 'NotAuthorizedException') {
            return createErrorResponse(401, 'Invalid username or password', headers);
        } else if (error.code === 'UserNotConfirmedException') {
            return createErrorResponse(400, 'User email not confirmed', headers);
        } else if (error.code === 'UserNotFoundException') {
            return createErrorResponse(401, 'Invalid username or password', headers);
        } else if (error.code === 'TooManyRequestsException') {
            return createErrorResponse(429, 'Too many requests. Please try again later.', headers);
        }

        return createErrorResponse(500, 'Login failed', headers);
    }
}

/**
 * Handle user registration
 */
async function handleRegister(body, headers) {
    try {
        // Validate input
        const { error, value } = registerSchema.validate(body);
        if (error) {
            return createErrorResponse(400, `Validation error: ${error.details[0].message}`, headers);
        }

        const { email, password, student_id, department, role } = value;

        console.log(`Registration attempt for user: ${email}`);

        // Prepare user attributes
        const userAttributes = [
            {
                Name: 'email',
                Value: email
            }
        ];

        if (student_id) {
            userAttributes.push({
                Name: 'custom:student_id',
                Value: student_id
            });
        }

        if (department) {
            userAttributes.push({
                Name: 'custom:department',
                Value: department
            });
        }

        userAttributes.push({
            Name: 'custom:role',
            Value: role
        });

        // Sign up user with Cognito
        const signUpParams = {
            ClientId: USER_POOL_CLIENT_ID,
            Username: email,
            Password: password,
            UserAttributes: userAttributes,
            MessageAction: 'CONFIRM'  // Send confirmation email
        };

        const signUpResult = await cognito.signUp(signUpParams).promise();

        console.log(`Registration successful for user: ${email}`);

        return {
            statusCode: 201,
            headers,
            body: JSON.stringify({
                success: true,
                message: 'Registration successful. Please check your email for verification code.',
                userSub: signUpResult.UserSub,
                codeDeliveryDetails: signUpResult.CodeDeliveryDetails
            })
        };

    } catch (error) {
        console.error('Registration error:', error);

        // Handle specific Cognito errors
        if (error.code === 'UsernameExistsException') {
            return createErrorResponse(400, 'User already exists', headers);
        } else if (error.code === 'InvalidPasswordException') {
            return createErrorResponse(400, 'Password does not meet requirements', headers);
        } else if (error.code === 'InvalidParameterException') {
            return createErrorResponse(400, error.message, headers);
        } else if (error.code === 'TooManyRequestsException') {
            return createErrorResponse(429, 'Too many requests. Please try again later.', headers);
        }

        return createErrorResponse(500, 'Registration failed', headers);
    }
}

/**
 * Handle email verification
 */
async function handleVerify(body, headers) {
    try {
        // Validate input
        const { error, value } = verifySchema.validate(body);
        if (error) {
            return createErrorResponse(400, `Validation error: ${error.details[0].message}`, headers);
        }

        const { username, confirmationCode } = value;

        console.log(`Email verification attempt for user: ${username}`);

        // Confirm sign up with Cognito
        const confirmParams = {
            ClientId: USER_POOL_CLIENT_ID,
            Username: username,
            ConfirmationCode: confirmationCode
        };

        await cognito.confirmSignUp(confirmParams).promise();

        console.log(`Email verification successful for user: ${username}`);

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                success: true,
                message: 'Email verification successful. You can now login.'
            })
        };

    } catch (error) {
        console.error('Verification error:', error);

        // Handle specific Cognito errors
        if (error.code === 'CodeMismatchException') {
            return createErrorResponse(400, 'Invalid verification code', headers);
        } else if (error.code === 'ExpiredCodeException') {
            return createErrorResponse(400, 'Verification code has expired', headers);
        } else if (error.code === 'UserNotFoundException') {
            return createErrorResponse(404, 'User not found', headers);
        } else if (error.code === 'NotAuthorizedException') {
            return createErrorResponse(400, 'User is already confirmed', headers);
        }

        return createErrorResponse(500, 'Email verification failed', headers);
    }
}

/**
 * Handle token refresh
 */
async function handleRefresh(body, headers, authorizer) {
    try {
        // Validate input
        const { error, value } = refreshSchema.validate(body);
        if (error) {
            return createErrorResponse(400, `Validation error: ${error.details[0].message}`, headers);
        }

        const { refreshToken } = value;

        console.log('Token refresh attempt');

        // Refresh tokens with Cognito
        const refreshParams = {
            AuthFlow: 'REFRESH_TOKEN_AUTH',
            ClientId: USER_POOL_CLIENT_ID,
            AuthParameters: {
                REFRESH_TOKEN: refreshToken
            }
        };

        const refreshResult = await cognito.initiateAuth(refreshParams).promise();

        console.log('Token refresh successful');

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                success: true,
                message: 'Token refresh successful',
                tokens: {
                    accessToken: refreshResult.AuthenticationResult.AccessToken,
                    idToken: refreshResult.AuthenticationResult.IdToken,
                    expiresIn: refreshResult.AuthenticationResult.ExpiresIn
                }
            })
        };

    } catch (error) {
        console.error('Token refresh error:', error);

        // Handle specific Cognito errors
        if (error.code === 'NotAuthorizedException') {
            return createErrorResponse(401, 'Invalid refresh token', headers);
        } else if (error.code === 'UserNotFoundException') {
            return createErrorResponse(404, 'User not found', headers);
        }

        return createErrorResponse(500, 'Token refresh failed', headers);
    }
}

/**
 * Get user information from Cognito
 */
async function getUserInfo(username) {
    try {
        const getUserParams = {
            UserPoolId: USER_POOL_ID,
            Username: username
        };

        const userResult = await cognito.adminGetUser(getUserParams).promise();

        // Extract user attributes
        const attributes = {};
        userResult.UserAttributes.forEach(attr => {
            const key = attr.Name.replace('custom:', '');
            attributes[key] = attr.Value;
        });

        return {
            username: userResult.Username,
            email: attributes.email,
            emailVerified: attributes.email_verified === 'true',
            status: userResult.UserStatus,
            created: userResult.UserCreateDate,
            lastModified: userResult.UserLastModifiedDate,
            studentId: attributes.student_id,
            department: attributes.department,
            role: attributes.role
        };

    } catch (error) {
        console.error('Error getting user info:', error);
        return null;
    }
}

/**
 * Create standardized error response
 */
function createErrorResponse(statusCode, message, headers) {
    return {
        statusCode,
        headers,
        body: JSON.stringify({
            success: false,
            error: {
                message,
                statusCode
            }
        })
    };
}
