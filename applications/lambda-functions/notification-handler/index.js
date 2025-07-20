/**
 * Notification Handler Lambda Function
 * 
 * This function processes notification requests and routes them to appropriate
 * channels (SNS topics, direct email, push notifications) based on user
 * preferences and notification types.
 * 
 * Features:
 * - Multi-channel notification routing
 * - User preference management
 * - Rate limiting and throttling
 * - Batch processing for efficiency
 * - Comprehensive error handling and logging
 * - Integration with Cognito for user data
 */

const { SNSClient, PublishCommand } = require('@aws-sdk/client-sns');
const { DynamoDBClient, GetItemCommand, PutItemCommand, UpdateItemCommand } = require('@aws-sdk/client-dynamodb');
const { CognitoIdentityProviderClient, AdminGetUserCommand } = require('@aws-sdk/client-cognito-identity-provider');
const { KMSClient, DecryptCommand } = require('@aws-sdk/client-kms');
const { marshall, unmarshall } = require('@aws-sdk/util-dynamodb');
const Joi = require('joi');
const { v4: uuidv4 } = require('uuid');
const moment = require('moment');

// Initialize AWS clients
const snsClient = new SNSClient({ region: process.env.AWS_REGION });
const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION });
const cognitoClient = new CognitoIdentityProviderClient({ region: process.env.AWS_REGION });
const kmsClient = new KMSClient({ region: process.env.AWS_REGION });

// Environment variables
const {
    PROJECT_NAME,
    ENVIRONMENT,
    SNS_TOPICS,
    NOTIFICATION_PREFERENCES_TABLE,
    USER_POOL_ID,
    RATE_LIMIT_PER_MINUTE,
    BATCH_SIZE,
    KMS_KEY_ARN
} = process.env;

// Parse SNS topics from environment
const snsTopics = JSON.parse(SNS_TOPICS || '{}');

// Validation schemas
const notificationSchema = Joi.object({
    userId: Joi.string().required(),
    type: Joi.string().valid('announcements', 'grades', 'attendance', 'assignments', 'system').required(),
    title: Joi.string().max(200).required(),
    message: Joi.string().max(2000).required(),
    priority: Joi.string().valid('low', 'medium', 'high', 'urgent').default('medium'),
    channels: Joi.array().items(Joi.string().valid('email', 'sms', 'push')).default(['email', 'push']),
    metadata: Joi.object().default({}),
    scheduledFor: Joi.date().iso().optional(),
    expiresAt: Joi.date().iso().optional()
});

const batchNotificationSchema = Joi.object({
    notifications: Joi.array().items(notificationSchema).min(1).max(parseInt(BATCH_SIZE) || 10).required(),
    batchId: Joi.string().optional()
});

/**
 * Main Lambda handler
 */
exports.handler = async (event, context) => {
    console.log('Notification Handler started', {
        requestId: context.awsRequestId,
        eventSource: event.Records ? 'SNS' : 'Direct',
        timestamp: new Date().toISOString()
    });

    try {
        // Handle SNS events (from other services)
        if (event.Records && event.Records[0].EventSource === 'aws:sns') {
            return await handleSNSEvent(event, context);
        }

        // Handle direct invocation
        return await handleDirectInvocation(event, context);

    } catch (error) {
        console.error('Handler error:', {
            error: error.message,
            stack: error.stack,
            requestId: context.awsRequestId
        });

        return {
            statusCode: 500,
            body: JSON.stringify({
                success: false,
                error: 'Internal server error',
                requestId: context.awsRequestId
            })
        };
    }
};

/**
 * Handle SNS events from other services
 */
async function handleSNSEvent(event, context) {
    const results = [];

    for (const record of event.Records) {
        try {
            const snsMessage = JSON.parse(record.Sns.Message);
            console.log('Processing SNS message:', {
                topicArn: record.Sns.TopicArn,
                messageId: record.Sns.MessageId,
                subject: record.Sns.Subject
            });

            const result = await processNotification(snsMessage, context);
            results.push(result);

        } catch (error) {
            console.error('SNS record processing error:', {
                error: error.message,
                messageId: record.Sns.MessageId,
                topicArn: record.Sns.TopicArn
            });
            results.push({ success: false, error: error.message });
        }
    }

    return {
        statusCode: 200,
        body: JSON.stringify({
            success: true,
            processedCount: results.length,
            results: results
        })
    };
}

/**
 * Handle direct function invocation
 */
async function handleDirectInvocation(event, context) {
    // Validate input
    const { error, value } = event.notifications 
        ? batchNotificationSchema.validate(event)
        : notificationSchema.validate(event);

    if (error) {
        console.error('Validation error:', error.details);
        return {
            statusCode: 400,
            body: JSON.stringify({
                success: false,
                error: 'Validation failed',
                details: error.details
            })
        };
    }

    // Process single or batch notifications
    if (value.notifications) {
        return await processBatchNotifications(value, context);
    } else {
        const result = await processNotification(value, context);
        return {
            statusCode: 200,
            body: JSON.stringify(result)
        };
    }
}

/**
 * Process batch notifications
 */
async function processBatchNotifications(batch, context) {
    const batchId = batch.batchId || uuidv4();
    console.log('Processing batch notifications:', {
        batchId,
        count: batch.notifications.length,
        requestId: context.awsRequestId
    });

    const results = [];
    const batchSize = parseInt(BATCH_SIZE) || 10;

    // Process in chunks to avoid timeout
    for (let i = 0; i < batch.notifications.length; i += batchSize) {
        const chunk = batch.notifications.slice(i, i + batchSize);
        const chunkPromises = chunk.map(notification => 
            processNotification(notification, context).catch(error => ({
                success: false,
                error: error.message,
                userId: notification.userId
            }))
        );

        const chunkResults = await Promise.all(chunkPromises);
        results.push(...chunkResults);
    }

    return {
        statusCode: 200,
        body: JSON.stringify({
            success: true,
            batchId,
            processedCount: results.length,
            successCount: results.filter(r => r.success).length,
            failureCount: results.filter(r => !r.success).length,
            results: results
        })
    };
}

/**
 * Process individual notification
 */
async function processNotification(notification, context) {
    const startTime = Date.now();
    const notificationId = uuidv4();

    console.log('Processing notification:', {
        notificationId,
        userId: notification.userId,
        type: notification.type,
        priority: notification.priority,
        channels: notification.channels
    });

    try {
        // Check rate limiting
        const rateLimitCheck = await checkRateLimit(notification.userId);
        if (!rateLimitCheck.allowed) {
            throw new Error(`Rate limit exceeded for user ${notification.userId}`);
        }

        // Get user preferences
        const userPreferences = await getUserNotificationPreferences(notification.userId);
        
        // Get user information from Cognito
        const userInfo = await getUserInfo(notification.userId);

        // Determine effective channels based on preferences
        const effectiveChannels = determineEffectiveChannels(
            notification.channels,
            userPreferences,
            notification.type
        );

        if (effectiveChannels.length === 0) {
            console.log('No channels enabled for notification:', {
                notificationId,
                userId: notification.userId,
                type: notification.type
            });
            return {
                success: true,
                notificationId,
                message: 'No channels enabled for this notification type',
                channelsProcessed: []
            };
        }

        // Process each channel
        const channelResults = [];
        for (const channel of effectiveChannels) {
            try {
                const result = await processNotificationChannel(
                    notification,
                    channel,
                    userInfo,
                    notificationId
                );
                channelResults.push(result);
            } catch (error) {
                console.error(`Channel processing error (${channel}):`, {
                    error: error.message,
                    notificationId,
                    userId: notification.userId
                });
                channelResults.push({
                    channel,
                    success: false,
                    error: error.message
                });
            }
        }

        // Update rate limiting counter
        await updateRateLimit(notification.userId);

        // Log notification processing
        await logNotification(notification, notificationId, channelResults);

        const processingTime = Date.now() - startTime;
        console.log('Notification processed successfully:', {
            notificationId,
            userId: notification.userId,
            channelsProcessed: channelResults.length,
            processingTimeMs: processingTime
        });

        return {
            success: true,
            notificationId,
            userId: notification.userId,
            type: notification.type,
            channelsProcessed: channelResults,
            processingTimeMs: processingTime
        };

    } catch (error) {
        console.error('Notification processing error:', {
            error: error.message,
            stack: error.stack,
            notificationId,
            userId: notification.userId
        });

        return {
            success: false,
            notificationId,
            userId: notification.userId,
            error: error.message
        };
    }
}

/**
 * Check rate limiting for user
 */
async function checkRateLimit(userId) {
    const rateLimitKey = `rate_limit_${userId}_${moment().format('YYYY-MM-DD-HH-mm')}`;
    
    try {
        const response = await dynamoClient.send(new GetItemCommand({
            TableName: NOTIFICATION_PREFERENCES_TABLE,
            Key: marshall({ user_id: rateLimitKey })
        }));

        const currentCount = response.Item ? unmarshall(response.Item).count || 0 : 0;
        const limit = parseInt(RATE_LIMIT_PER_MINUTE) || 10;

        return {
            allowed: currentCount < limit,
            currentCount,
            limit
        };
    } catch (error) {
        console.error('Rate limit check error:', error);
        return { allowed: true, currentCount: 0, limit: 10 }; // Allow on error
    }
}

/**
 * Update rate limiting counter
 */
async function updateRateLimit(userId) {
    const rateLimitKey = `rate_limit_${userId}_${moment().format('YYYY-MM-DD-HH-mm')}`;
    const expiresAt = moment().add(2, 'minutes').unix(); // Expire after 2 minutes

    try {
        await dynamoClient.send(new UpdateItemCommand({
            TableName: NOTIFICATION_PREFERENCES_TABLE,
            Key: marshall({ user_id: rateLimitKey }),
            UpdateExpression: 'ADD #count :inc SET #expires :expires',
            ExpressionAttributeNames: {
                '#count': 'count',
                '#expires': 'expires_at'
            },
            ExpressionAttributeValues: marshall({
                ':inc': 1,
                ':expires': expiresAt
            })
        }));
    } catch (error) {
        console.error('Rate limit update error:', error);
        // Don't throw - this is not critical
    }
}

/**
 * Get user notification preferences
 */
async function getUserNotificationPreferences(userId) {
    try {
        const response = await dynamoClient.send(new GetItemCommand({
            TableName: NOTIFICATION_PREFERENCES_TABLE,
            Key: marshall({ user_id: userId })
        }));

        if (response.Item) {
            return unmarshall(response.Item);
        }

        // Return default preferences if none exist
        const defaultPreferences = {
            user_id: userId,
            email_enabled: true,
            sms_enabled: false,
            push_enabled: true,
            topics: {
                announcements: { email: true, sms: false, push: true },
                grades: { email: true, sms: false, push: true },
                attendance: { email: true, sms: false, push: true },
                assignments: { email: true, sms: false, push: true },
                system: { email: true, sms: false, push: false }
            },
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
        };

        // Save default preferences
        await dynamoClient.send(new PutItemCommand({
            TableName: NOTIFICATION_PREFERENCES_TABLE,
            Item: marshall(defaultPreferences)
        }));

        return defaultPreferences;
    } catch (error) {
        console.error('Error getting user preferences:', error);
        // Return safe defaults on error
        return {
            email_enabled: true,
            sms_enabled: false,
            push_enabled: true,
            topics: {
                [notification.type]: { email: true, sms: false, push: true }
            }
        };
    }
}

/**
 * Get user information from Cognito
 */
async function getUserInfo(userId) {
    if (!USER_POOL_ID) {
        return { userId, email: null, phone: null, name: null };
    }

    try {
        const response = await cognitoClient.send(new AdminGetUserCommand({
            UserPoolId: USER_POOL_ID,
            Username: userId
        }));

        const attributes = {};
        if (response.UserAttributes) {
            response.UserAttributes.forEach(attr => {
                attributes[attr.Name] = attr.Value;
            });
        }

        return {
            userId,
            email: attributes.email || null,
            phone: attributes.phone_number || null,
            name: attributes.name || attributes.given_name || null,
            role: attributes['custom:role'] || 'student',
            department: attributes['custom:department'] || null,
            enabled: response.Enabled,
            status: response.UserStatus
        };
    } catch (error) {
        console.error('Error getting user info:', error);
        return { userId, email: null, phone: null, name: null };
    }
}

/**
 * Determine effective notification channels
 */
function determineEffectiveChannels(requestedChannels, userPreferences, notificationType) {
    const effectiveChannels = [];

    for (const channel of requestedChannels) {
        // Check global channel preference
        const globalEnabled = userPreferences[`${channel}_enabled`];
        if (!globalEnabled) continue;

        // Check topic-specific preference
        const topicPrefs = userPreferences.topics?.[notificationType];
        if (topicPrefs && topicPrefs[channel]) {
            effectiveChannels.push(channel);
        }
    }

    return effectiveChannels;
}

/**
 * Process notification for specific channel
 */
async function processNotificationChannel(notification, channel, userInfo, notificationId) {
    console.log(`Processing ${channel} channel:`, {
        notificationId,
        userId: notification.userId,
        type: notification.type
    });

    switch (channel) {
        case 'email':
            return await processEmailChannel(notification, userInfo, notificationId);
        case 'sms':
            return await processSMSChannel(notification, userInfo, notificationId);
        case 'push':
            return await processPushChannel(notification, userInfo, notificationId);
        default:
            throw new Error(`Unsupported channel: ${channel}`);
    }
}

/**
 * Process email channel
 */
async function processEmailChannel(notification, userInfo, notificationId) {
    if (!userInfo.email) {
        throw new Error('User email not available');
    }

    // Publish to email sender Lambda via SNS
    const emailPayload = {
        notificationId,
        userId: notification.userId,
        email: userInfo.email,
        name: userInfo.name,
        type: notification.type,
        title: notification.title,
        message: notification.message,
        priority: notification.priority,
        metadata: notification.metadata
    };

    const topicArn = snsTopics.system; // Use system topic for internal processing
    await snsClient.send(new PublishCommand({
        TopicArn: topicArn,
        Message: JSON.stringify(emailPayload),
        Subject: `Email Notification: ${notification.title}`,
        MessageAttributes: {
            channel: { DataType: 'String', StringValue: 'email' },
            type: { DataType: 'String', StringValue: notification.type },
            priority: { DataType: 'String', StringValue: notification.priority }
        }
    }));

    return {
        channel: 'email',
        success: true,
        recipient: userInfo.email,
        messageId: notificationId
    };
}

/**
 * Process SMS channel
 */
async function processSMSChannel(notification, userInfo, notificationId) {
    if (!userInfo.phone) {
        throw new Error('User phone number not available');
    }

    // Publish SMS notification
    const smsMessage = `${notification.title}\n\n${notification.message}`;
    
    await snsClient.send(new PublishCommand({
        PhoneNumber: userInfo.phone,
        Message: smsMessage,
        MessageAttributes: {
            'AWS.SNS.SMS.SenderID': { DataType: 'String', StringValue: 'EduPlatform' },
            'AWS.SNS.SMS.SMSType': { DataType: 'String', StringValue: 'Transactional' }
        }
    }));

    return {
        channel: 'sms',
        success: true,
        recipient: userInfo.phone,
        messageId: notificationId
    };
}

/**
 * Process push notification channel
 */
async function processPushChannel(notification, userInfo, notificationId) {
    // Publish to push notification topic
    const pushPayload = {
        notificationId,
        userId: notification.userId,
        type: notification.type,
        title: notification.title,
        message: notification.message,
        priority: notification.priority,
        metadata: notification.metadata
    };

    const topicArn = snsTopics[notification.type] || snsTopics.system;
    await snsClient.send(new PublishCommand({
        TopicArn: topicArn,
        Message: JSON.stringify(pushPayload),
        Subject: notification.title,
        MessageAttributes: {
            channel: { DataType: 'String', StringValue: 'push' },
            type: { DataType: 'String', StringValue: notification.type },
            priority: { DataType: 'String', StringValue: notification.priority }
        }
    }));

    return {
        channel: 'push',
        success: true,
        topicArn: topicArn,
        messageId: notificationId
    };
}

/**
 * Log notification processing
 */
async function logNotification(notification, notificationId, channelResults) {
    const logEntry = {
        user_id: `notification_log_${notificationId}`,
        notification_id: notificationId,
        user_id_original: notification.userId,
        type: notification.type,
        title: notification.title,
        priority: notification.priority,
        channels_requested: notification.channels,
        channels_processed: channelResults.map(r => r.channel),
        success_count: channelResults.filter(r => r.success).length,
        failure_count: channelResults.filter(r => !r.success).length,
        created_at: new Date().toISOString(),
        expires_at: moment().add(30, 'days').unix() // Auto-cleanup after 30 days
    };

    try {
        await dynamoClient.send(new PutItemCommand({
            TableName: NOTIFICATION_PREFERENCES_TABLE,
            Item: marshall(logEntry)
        }));
    } catch (error) {
        console.error('Error logging notification:', error);
        // Don't throw - logging is not critical
    }
}