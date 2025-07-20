/**
 * AWS Education Platform - Post-Confirmation Lambda Function
 * 
 * This Lambda function is triggered after a user confirms their email address.
 * It performs post-signup setup tasks such as:
 * - Adding user to appropriate groups
 * - Creating user profile records
 * - Sending welcome notifications
 * - Setting up initial permissions
 */

const AWS = require('aws-sdk');

// Initialize AWS services
const cognito = new AWS.CognitoIdentityServiceProvider({
    region: process.env.REGION
});

const USER_POOL_ID = process.env.USER_POOL_ID;

exports.handler = async (event) => {
    console.log('Post-confirmation event:', JSON.stringify(event, null, 2));

    try {
        const { request, userPoolId, userName } = event;
        const { userAttributes } = request;

        // Extract user information
        const email = userAttributes.email;
        const customRole = userAttributes['custom:role'];
        const customStudentId = userAttributes['custom:student_id'];
        const customDepartment = userAttributes['custom:department'];

        console.log(`Post-confirmation setup for: ${email}, role: ${customRole}`);

        // 1. Add user to appropriate group based on role
        await addUserToGroup(userName, customRole);

        // 2. Create user profile in DynamoDB (if needed)
        await createUserProfile(userName, userAttributes);

        // 3. Send welcome notification
        await sendWelcomeNotification(email, customRole);

        // 4. Set up role-specific permissions
        await setupRoleSpecificPermissions(userName, customRole);

        // 5. Log successful completion
        console.log(`Post-confirmation setup completed successfully for: ${email}`);

        return event;

    } catch (error) {
        console.error('Post-confirmation error:', error);
        
        // Note: We don't throw the error here because the user has already been confirmed
        // Instead, we log the error and potentially send an alert for manual intervention
        console.error(`Manual intervention required for user: ${event.userName}`);
        
        return event;
    }
};

/**
 * Add user to appropriate Cognito group based on their role
 */
async function addUserToGroup(userName, role) {
    try {
        let groupName;
        
        switch (role) {
            case 'student':
                groupName = 'students';
                break;
            case 'teacher':
                groupName = 'teachers';
                break;
            case 'admin':
                groupName = 'admins';
                break;
            default:
                console.log(`Unknown role: ${role}, defaulting to students group`);
                groupName = 'students';
        }

        const params = {
            GroupName: groupName,
            UserPoolId: USER_POOL_ID,
            Username: userName
        };

        await cognito.adminAddUserToGroup(params).promise();
        console.log(`User ${userName} added to group: ${groupName}`);

    } catch (error) {
        console.error(`Error adding user to group:`, error);
        throw error;
    }
}

/**
 * Create user profile record (placeholder for DynamoDB integration)
 */
async function createUserProfile(userName, userAttributes) {
    try {
        // In a real implementation, this would create a user profile in DynamoDB
        // For now, we'll just log the profile creation
        
        const profile = {
            userId: userName,
            email: userAttributes.email,
            role: userAttributes['custom:role'],
            studentId: userAttributes['custom:student_id'],
            department: userAttributes['custom:department'],
            createdAt: new Date().toISOString(),
            status: 'active',
            preferences: {
                emailNotifications: true,
                pushNotifications: true,
                theme: 'light'
            }
        };

        console.log(`Creating user profile:`, JSON.stringify(profile, null, 2));

        // TODO: Integrate with DynamoDB when user profiles table is created
        // const dynamodb = new AWS.DynamoDB.DocumentClient();
        // await dynamodb.put({
        //     TableName: 'UserProfiles',
        //     Item: profile
        // }).promise();

    } catch (error) {
        console.error('Error creating user profile:', error);
        throw error;
    }
}

/**
 * Send welcome notification to new user
 */
async function sendWelcomeNotification(email, role) {
    try {
        // In a real implementation, this would integrate with SNS/SES
        // For now, we'll just log the welcome message
        
        const welcomeMessages = {
            student: 'Welcome to the Education Platform! You can now access courses, view lectures, and track your progress.',
            teacher: 'Welcome to the Education Platform! You can now create courses, upload content, and manage your classes.',
            admin: 'Welcome to the Education Platform! You have administrative access to manage users and system settings.'
        };

        const message = welcomeMessages[role] || welcomeMessages.student;
        
        console.log(`Sending welcome notification to ${email}: ${message}`);

        // TODO: Integrate with SNS/SES when notification system is created
        // const sns = new AWS.SNS();
        // await sns.publish({
        //     TopicArn: 'arn:aws:sns:region:account:welcome-notifications',
        //     Message: JSON.stringify({
        //         email: email,
        //         message: message,
        //         type: 'welcome'
        //     })
        // }).promise();

    } catch (error) {
        console.error('Error sending welcome notification:', error);
        // Don't throw error for notification failures
    }
}

/**
 * Set up role-specific permissions and configurations
 */
async function setupRoleSpecificPermissions(userName, role) {
    try {
        console.log(`Setting up role-specific permissions for ${userName} with role: ${role}`);

        switch (role) {
            case 'student':
                await setupStudentPermissions(userName);
                break;
            case 'teacher':
                await setupTeacherPermissions(userName);
                break;
            case 'admin':
                await setupAdminPermissions(userName);
                break;
            default:
                console.log(`Unknown role: ${role}, using default student permissions`);
                await setupStudentPermissions(userName);
        }

    } catch (error) {
        console.error('Error setting up role-specific permissions:', error);
        throw error;
    }
}

/**
 * Set up student-specific permissions
 */
async function setupStudentPermissions(userName) {
    console.log(`Setting up student permissions for: ${userName}`);
    
    // In a real implementation, this might:
    // - Create student-specific S3 folders
    // - Set up course enrollment capabilities
    // - Configure grade viewing permissions
    // - Set up chat access
    
    // For now, just log the setup
    console.log(`Student permissions configured for: ${userName}`);
}

/**
 * Set up teacher-specific permissions
 */
async function setupTeacherPermissions(userName) {
    console.log(`Setting up teacher permissions for: ${userName}`);
    
    // In a real implementation, this might:
    // - Create teacher content folders in S3
    // - Set up course creation permissions
    // - Configure grade management access
    // - Set up video upload capabilities
    
    console.log(`Teacher permissions configured for: ${userName}`);
}

/**
 * Set up admin-specific permissions
 */
async function setupAdminPermissions(userName) {
    console.log(`Setting up admin permissions for: ${userName}`);
    
    // In a real implementation, this might:
    // - Grant system administration access
    // - Set up monitoring dashboard access
    // - Configure user management permissions
    // - Set up system configuration access
    
    console.log(`Admin permissions configured for: ${userName}`);
}

/**
 * Helper function to validate required attributes
 */
function validateUserAttributes(userAttributes) {
    const required = ['email', 'custom:role'];
    const missing = required.filter(attr => !userAttributes[attr]);
    
    if (missing.length > 0) {
        throw new Error(`Missing required attributes: ${missing.join(', ')}`);
    }
    
    return true;
}

/**
 * Helper function to sanitize user data
 */
function sanitizeUserData(userAttributes) {
    const sanitized = {};
    
    Object.keys(userAttributes).forEach(key => {
        if (userAttributes[key]) {
            sanitized[key] = userAttributes[key].trim();
        }
    });
    
    return sanitized;
}
