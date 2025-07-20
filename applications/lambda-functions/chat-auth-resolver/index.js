const { CognitoIdentityProviderClient, GetUserCommand } = require('@aws-sdk/client-cognito-identity-provider');
const jwt = require('jsonwebtoken');

// Initialize Cognito client
const cognitoClient = new CognitoIdentityProviderClient({ region: process.env.AWS_REGION });

// Environment variables
const USER_POOL_ID = process.env.USER_POOL_ID;

// Utility functions
const logger = {
  info: (message, data) => console.log(JSON.stringify({ level: 'INFO', message, data, timestamp: new Date().toISOString() })),
  error: (message, error) => console.error(JSON.stringify({ level: 'ERROR', message, error: error.message, stack: error.stack, timestamp: new Date().toISOString() })),
  debug: (message, data) => {
    if (process.env.LOG_LEVEL === 'DEBUG') {
      console.log(JSON.stringify({ level: 'DEBUG', message, data, timestamp: new Date().toISOString() }));
    }
  }
};

// Main authorization handler for AppSync
exports.handler = async (event) => {
  logger.debug('Auth resolver received event', event);

  try {
    const { authorizationToken, requestContext } = event;

    if (!authorizationToken) {
      logger.error('No authorization token provided');
      return generateDenyResponse('Unauthorized', 'No authorization token');
    }

    // Extract token from Bearer format
    const token = authorizationToken.replace('Bearer ', '');
    
    // Validate and decode the JWT token
    const decodedToken = await validateToken(token);
    
    if (!decodedToken) {
      logger.error('Invalid or expired token');
      return generateDenyResponse('Unauthorized', 'Invalid token');
    }

    // Get user information from Cognito
    const userInfo = await getUserInfo(token);
    
    if (!userInfo) {
      logger.error('User not found in Cognito');
      return generateDenyResponse('Unauthorized', 'User not found');
    }

    // Check if user is active
    if (userInfo.UserStatus !== 'CONFIRMED') {
      logger.error('User account not confirmed', { status: userInfo.UserStatus });
      return generateDenyResponse('Unauthorized', 'Account not confirmed');
    }

    // Extract user attributes
    const userAttributes = parseUserAttributes(userInfo.UserAttributes);
    
    // Generate successful authorization response
    const response = generateAllowResponse(decodedToken.sub, {
      sub: decodedToken.sub,
      username: userInfo.Username,
      email: userAttributes.email,
      role: userAttributes['custom:role'] || 'student',
      department: userAttributes['custom:department'] || '',
      student_id: userAttributes['custom:student_id'] || '',
      groups: decodedToken['cognito:groups'] || [],
      token_use: decodedToken.token_use,
      iss: decodedToken.iss,
      exp: decodedToken.exp,
      iat: decodedToken.iat
    });

    logger.info('Authorization successful', { 
      userId: decodedToken.sub, 
      username: userInfo.Username,
      role: userAttributes['custom:role']
    });

    return response;

  } catch (error) {
    logger.error('Authorization error', error);
    return generateDenyResponse('Unauthorized', 'Authorization failed');
  }
};

// Validate JWT token (basic validation without signature verification for demo)
async function validateToken(token) {
  try {
    // In production, you should verify the signature against Cognito public keys
    // For this demo, we'll do basic JWT parsing and expiration check
    const decoded = jwt.decode(token);
    
    if (!decoded) {
      logger.error('Failed to decode JWT token');
      return null;
    }

    // Check token expiration
    const currentTime = Math.floor(Date.now() / 1000);
    if (decoded.exp < currentTime) {
      logger.error('Token has expired', { exp: decoded.exp, current: currentTime });
      return null;
    }

    // Check token issuer (should be Cognito)
    const expectedIssuer = `https://cognito-idp.${process.env.AWS_REGION}.amazonaws.com/${USER_POOL_ID}`;
    if (decoded.iss !== expectedIssuer) {
      logger.error('Invalid token issuer', { iss: decoded.iss, expected: expectedIssuer });
      return null;
    }

    // Check token use (should be 'access' for API access)
    if (decoded.token_use !== 'access') {
      logger.error('Invalid token use', { token_use: decoded.token_use });
      return null;
    }

    return decoded;

  } catch (error) {
    logger.error('Token validation error', error);
    return null;
  }
}

// Get user information from Cognito
async function getUserInfo(accessToken) {
  try {
    const command = new GetUserCommand({
      AccessToken: accessToken
    });

    const response = await cognitoClient.send(command);
    return response;

  } catch (error) {
    logger.error('Failed to get user info from Cognito', error);
    return null;
  }
}

// Parse Cognito user attributes into key-value pairs
function parseUserAttributes(attributes) {
  const parsed = {};
  
  if (attributes && Array.isArray(attributes)) {
    for (const attr of attributes) {
      parsed[attr.Name] = attr.Value;
    }
  }
  
  return parsed;
}

// Generate allow response for AppSync authorization
function generateAllowResponse(principalId, context) {
  return {
    isAuthorized: true,
    resolverContext: context,
    deniedFields: [], // No field-level restrictions
    ttlOverride: 300 // Cache for 5 minutes
  };
}

// Generate deny response for AppSync authorization
function generateDenyResponse(principalId, reason) {
  return {
    isAuthorized: false,
    resolverContext: {
      error: reason,
      timestamp: new Date().toISOString()
    },
    deniedFields: ['*'], // Deny all fields
    ttlOverride: 0 // Don't cache deny responses
  };
}

// Role-based authorization helper (for future use)
function hasPermission(userRole, requiredRole) {
  const roleHierarchy = {
    'admin': ['admin', 'teacher', 'student'],
    'teacher': ['teacher', 'student'],
    'student': ['student']
  };

  return roleHierarchy[userRole]?.includes(requiredRole) || false;
}

// Group-based authorization helper (for future use)
function hasGroup(userGroups, requiredGroup) {
  return Array.isArray(userGroups) && userGroups.includes(requiredGroup);
}

// Export helper functions for testing
module.exports = {
  handler: exports.handler,
  validateToken,
  getUserInfo,
  parseUserAttributes,
  hasPermission,
  hasGroup
};
