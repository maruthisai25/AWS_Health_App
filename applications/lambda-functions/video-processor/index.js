const AWS = require('aws-sdk');

// Initialize AWS services
const elasticTranscoder = new AWS.ElasticTranscoder();
const s3 = new AWS.S3();
const sns = new AWS.SNS();

// Environment variables
const {
    TRANSCODER_PIPELINE_ID,
    RAW_BUCKET,
    TRANSCODED_BUCKET,
    SNS_TOPIC_ARN,
    PRESETS,
    LOG_LEVEL = 'INFO'
} = process.env;

// Parse presets from environment
let transcodingPresets = {};
try {
    transcodingPresets = JSON.parse(PRESETS || '{}');
} catch (error) {
    console.error('Error parsing PRESETS environment variable:', error);
}

/**
 * AWS Lambda handler for video processing
 * Triggered when videos are uploaded to the raw videos S3 bucket
 */
exports.handler = async (event) => {
    console.log('Video processor started');
    console.log('Event:', JSON.stringify(event, null, 2));

    const results = [];

    try {
        // Process each S3 record in the event
        for (const record of event.Records) {
            if (record.eventSource === 'aws:s3' && record.eventName.startsWith('ObjectCreated')) {
                const result = await processVideoUpload(record);
                results.push(result);
            }
        }

        console.log('All videos processed successfully');
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: 'Video processing completed',
                results: results,
                processedCount: results.length
            })
        };

    } catch (error) {
        console.error('Error in video processing:', error);
        
        // Send error notification
        await sendNotification({
            subject: 'Video Processing Error',
            message: `Error processing videos: ${error.message}`,
            error: error
        });

        throw error;
    }
};

/**
 * Process a single video upload from S3 event
 */
async function processVideoUpload(s3Record) {
    const bucket = s3Record.s3.bucket.name;
    const key = decodeURIComponent(s3Record.s3.object.key.replace(/\+/g, ' '));
    
    console.log(`Processing video: ${bucket}/${key}`);

    try {
        // Validate the uploaded file
        const fileInfo = await validateVideoFile(bucket, key);
        console.log('File validation passed:', fileInfo);

        // Create transcoding jobs for different presets
        const transcodingJobs = await createTranscodingJobs(key, fileInfo);
        console.log(`Created ${transcodingJobs.length} transcoding jobs`);

        // Send success notification
        await sendNotification({
            subject: 'Video Processing Started',
            message: `Started processing video: ${key}`,
            details: {
                originalFile: key,
                fileSize: fileInfo.size,
                jobsCreated: transcodingJobs.length
            }
        });

        return {
            success: true,
            file: key,
            fileSize: fileInfo.size,
            jobsCreated: transcodingJobs.length,
            jobIds: transcodingJobs.map(job => job.Job.Id)
        };

    } catch (error) {
        console.error(`Error processing ${key}:`, error);
        
        await sendNotification({
            subject: 'Video Processing Failed',
            message: `Failed to process video: ${key}`,
            error: error.message
        });

        return {
            success: false,
            file: key,
            error: error.message
        };
    }
}

/**
 * Validate uploaded video file
 */
async function validateVideoFile(bucket, key) {
    try {
        // Get file metadata
        const headParams = {
            Bucket: bucket,
            Key: key
        };

        const metadata = await s3.headObject(headParams).promise();
        
        // Extract file information
        const fileSize = metadata.ContentLength;
        const lastModified = metadata.LastModified;
        const contentType = metadata.ContentType || '';
        
        // Get file extension
        const fileExtension = key.split('.').pop().toLowerCase();
        
        console.log(`File info: ${key}, Size: ${fileSize} bytes, Type: ${contentType}, Extension: ${fileExtension}`);

        // Validate file size (from environment variable)
        const maxSizeMB = parseInt(process.env.MAX_FILE_SIZE_MB || '5000');
        const maxSizeBytes = maxSizeMB * 1024 * 1024;
        
        if (fileSize > maxSizeBytes) {
            throw new Error(`File size ${Math.round(fileSize / 1024 / 1024)}MB exceeds maximum allowed size of ${maxSizeMB}MB`);
        }

        // Validate file format
        const allowedFormats = (process.env.ALLOWED_FORMATS || 'mp4,mov,avi,mkv,webm,m4v').split(',');
        
        if (!allowedFormats.includes(fileExtension)) {
            throw new Error(`File format '${fileExtension}' is not allowed. Allowed formats: ${allowedFormats.join(', ')}`);
        }

        return {
            size: fileSize,
            contentType: contentType,
            extension: fileExtension,
            lastModified: lastModified
        };

    } catch (error) {
        if (error.code === 'NoSuchKey') {
            throw new Error(`File not found: ${key}`);
        }
        throw error;
    }
}

/**
 * Create transcoding jobs for different quality presets
 */
async function createTranscodingJobs(inputKey, fileInfo) {
    const jobs = [];
    
    // Get the filename without extension
    const baseName = inputKey.replace(/\.[^/.]+$/, '');
    
    // Create jobs for each enabled preset
    for (const [presetName, presetId] of Object.entries(transcodingPresets)) {
        if (!presetId) {
            console.log(`Skipping preset ${presetName} - not configured`);
            continue;
        }

        try {
            const outputKey = `${baseName}_${presetName}.${getOutputExtension(presetName)}`;
            
            const jobParams = {
                PipelineId: TRANSCODER_PIPELINE_ID,
                Input: {
                    Key: inputKey,
                    FrameRate: 'auto',
                    Resolution: 'auto',
                    AspectRatio: 'auto',
                    Interlaced: 'auto',
                    Container: 'auto'
                },
                Output: {
                    Key: outputKey,
                    PresetId: presetId,
                    ThumbnailPattern: `${baseName}_${presetName}_thumb_{count}`,
                    Rotate: 'auto'
                },
                UserMetadata: {
                    originalFile: inputKey,
                    preset: presetName,
                    uploadTime: new Date().toISOString(),
                    fileSize: fileInfo.size.toString()
                }
            };

            console.log(`Creating transcoding job for preset ${presetName}`);
            const job = await elasticTranscoder.createJob(jobParams).promise();
            
            console.log(`Created job ${job.Job.Id} for preset ${presetName}`);
            jobs.push(job);

        } catch (error) {
            console.error(`Failed to create job for preset ${presetName}:`, error);
            // Continue with other presets even if one fails
        }
    }

    if (jobs.length === 0) {
        throw new Error('No transcoding jobs could be created');
    }

    return jobs;
}

/**
 * Get output file extension based on preset
 */
function getOutputExtension(presetName) {
    const extensionMap = {
        '1080p': 'mp4',
        '720p': 'mp4', 
        '480p': 'mp4',
        'hls': 'm3u8'
    };
    
    return extensionMap[presetName] || 'mp4';
}

/**
 * Send notification via SNS
 */
async function sendNotification(notification) {
    if (!SNS_TOPIC_ARN) {
        console.log('SNS topic not configured, skipping notification');
        return;
    }

    try {
        const message = {
            timestamp: new Date().toISOString(),
            service: 'video-processor',
            ...notification
        };

        const params = {
            TopicArn: SNS_TOPIC_ARN,
            Subject: notification.subject,
            Message: JSON.stringify(message, null, 2)
        };

        await sns.publish(params).promise();
        console.log('Notification sent successfully');

    } catch (error) {
        console.error('Failed to send notification:', error);
        // Don't throw error for notification failures
    }
}

/**
 * Utility function to log with levels
 */
function log(level, message, data = null) {
    const logLevels = ['DEBUG', 'INFO', 'WARN', 'ERROR'];
    const currentLevelIndex = logLevels.indexOf(LOG_LEVEL);
    const messageLevelIndex = logLevels.indexOf(level);
    
    if (messageLevelIndex >= currentLevelIndex) {
        const logEntry = {
            level: level,
            timestamp: new Date().toISOString(),
            message: message
        };
        
        if (data) {
            logEntry.data = data;
        }
        
        console.log(JSON.stringify(logEntry));
    }
}