const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');

// Initialize AWS services
const s3 = new AWS.S3({
    signatureVersion: 'v4'
});
const cloudfront = new AWS.CloudFront();

// Environment variables
const {
    RAW_BUCKET,
    TRANSCODED_BUCKET,
    CLOUDFRONT_DOMAIN,
    ENABLE_SIGNED_URLS,
    URL_EXPIRATION_HOURS = '24',
    MAX_FILE_SIZE_MB = '5000',
    ALLOWED_FORMATS = 'mp4,mov,avi,mkv,webm,m4v',
    MULTIPART_THRESHOLD_MB = '100',
    ENABLE_MULTIPART = 'true',
    LOG_LEVEL = 'INFO'
} = process.env;

const URL_EXPIRATION_SECONDS = parseInt(URL_EXPIRATION_HOURS) * 3600;
const MAX_FILE_SIZE_BYTES = parseInt(MAX_FILE_SIZE_MB) * 1024 * 1024;
const MULTIPART_THRESHOLD_BYTES = parseInt(MULTIPART_THRESHOLD_MB) * 1024 * 1024;

/**
 * AWS Lambda handler for generating presigned URLs
 * Supports both upload and download URL generation
 */
exports.handler = async (event) => {
    console.log('Presigned URL generator started');
    console.log('Event:', JSON.stringify(event, null, 2));

    try {
        // Parse the request body
        const body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
        const { action, ...params } = body;

        let result;

        switch (action) {
            case 'generateUploadUrl':
                result = await generateUploadUrl(params);
                break;
            case 'generateDownloadUrl':
                result = await generateDownloadUrl(params);
                break;
            case 'generateMultipartUpload':
                result = await generateMultipartUpload(params);
                break;
            case 'completeMultipartUpload':
                result = await completeMultipartUpload(params);
                break;
            case 'abortMultipartUpload':
                result = await abortMultipartUpload(params);
                break;
            default:
                throw new Error(`Unknown action: ${action}`);
        }

        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                'Access-Control-Allow-Methods': 'POST,OPTIONS'
            },
            body: JSON.stringify({
                success: true,
                data: result
            })
        };

    } catch (error) {
        console.error('Error generating presigned URL:', error);

        return {
            statusCode: 400,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                success: false,
                error: error.message
            })
        };
    }
};

/**
 * Generate presigned URL for video upload
 */
async function generateUploadUrl({ fileName, fileSize, contentType, userId, courseId, metadata = {} }) {
    console.log(`Generating upload URL for: ${fileName}`);

    // Validate inputs
    validateUploadRequest({ fileName, fileSize, contentType });

    // Generate unique file key
    const fileExtension = fileName.split('.').pop().toLowerCase();
    const uniqueId = uuidv4();
    const sanitizedFileName = fileName.replace(/[^a-zA-Z0-9.-]/g, '_');
    const fileKey = `uploads/${userId || 'anonymous'}/${courseId || 'general'}/${uniqueId}_${sanitizedFileName}`;

    // Determine if multipart upload should be used
    const useMultipart = ENABLE_MULTIPART === 'true' && fileSize > MULTIPART_THRESHOLD_BYTES;

    if (useMultipart) {
        return await generateMultipartUpload({ 
            fileKey, 
            contentType, 
            fileSize, 
            metadata: {
                ...metadata,
                originalFileName: fileName,
                userId,
                courseId,
                uploadTimestamp: new Date().toISOString()
            }
        });
    }

    // Generate single presigned URL
    const params = {
        Bucket: RAW_BUCKET,
        Key: fileKey,
        Expires: URL_EXPIRATION_SECONDS,
        ContentType: contentType,
        Conditions: [
            ['content-length-range', 0, MAX_FILE_SIZE_BYTES]
        ],
        Fields: {
            'Content-Type': contentType,
            ...Object.keys(metadata).reduce((acc, key) => {
                acc[`x-amz-meta-${key}`] = metadata[key];
                return acc;
            }, {})
        }
    };

    const presignedPost = await s3.createPresignedPost(params);

    return {
        uploadType: 'single',
        uploadUrl: presignedPost.url,
        fields: presignedPost.fields,
        fileKey: fileKey,
        expiresAt: new Date(Date.now() + URL_EXPIRATION_SECONDS * 1000).toISOString(),
        maxFileSize: MAX_FILE_SIZE_BYTES
    };
}

/**
 * Generate multipart upload for large files
 */
async function generateMultipartUpload({ fileKey, contentType, fileSize, metadata = {} }) {
    console.log(`Generating multipart upload for: ${fileKey}`);

    const params = {
        Bucket: RAW_BUCKET,
        Key: fileKey,
        ContentType: contentType,
        Metadata: {
            ...metadata,
            fileSize: fileSize.toString(),
            uploadType: 'multipart'
        }
    };

    const multipartUpload = await s3.createMultipartUpload(params).promise();

    // Calculate number of parts (5MB minimum per part, except last part)
    const partSize = Math.max(5 * 1024 * 1024, Math.ceil(fileSize / 1000)); // Max 1000 parts
    const numParts = Math.ceil(fileSize / partSize);

    // Generate presigned URLs for each part
    const partUrls = [];
    for (let i = 1; i <= numParts; i++) {
        const partParams = {
            Bucket: RAW_BUCKET,
            Key: fileKey,
            PartNumber: i,
            UploadId: multipartUpload.UploadId,
            Expires: URL_EXPIRATION_SECONDS
        };

        const partUrl = await s3.getSignedUrlPromise('uploadPart', partParams);
        partUrls.push({
            partNumber: i,
            uploadUrl: partUrl,
            size: i === numParts ? fileSize - (partSize * (i - 1)) : partSize
        });
    }

    return {
        uploadType: 'multipart',
        uploadId: multipartUpload.UploadId,
        fileKey: fileKey,
        partSize: partSize,
        totalParts: numParts,
        partUrls: partUrls,
        expiresAt: new Date(Date.now() + URL_EXPIRATION_SECONDS * 1000).toISOString()
    };
}

/**
 * Complete multipart upload
 */
async function completeMultipartUpload({ fileKey, uploadId, parts }) {
    console.log(`Completing multipart upload for: ${fileKey}`);

    const params = {
        Bucket: RAW_BUCKET,
        Key: fileKey,
        UploadId: uploadId,
        MultipartUpload: {
            Parts: parts.map(part => ({
                ETag: part.etag,
                PartNumber: part.partNumber
            }))
        }
    };

    const result = await s3.completeMultipartUpload(params).promise();

    return {
        success: true,
        location: result.Location,
        fileKey: fileKey,
        etag: result.ETag
    };
}

/**
 * Abort multipart upload
 */
async function abortMultipartUpload({ fileKey, uploadId }) {
    console.log(`Aborting multipart upload for: ${fileKey}`);

    const params = {
        Bucket: RAW_BUCKET,
        Key: fileKey,
        UploadId: uploadId
    };

    await s3.abortMultipartUpload(params).promise();

    return {
        success: true,
        message: 'Multipart upload aborted successfully'
    };
}

/**
 * Generate presigned URL for video download
 */
async function generateDownloadUrl({ fileKey, userId, quality = 'original' }) {
    console.log(`Generating download URL for: ${fileKey}, quality: ${quality}`);

    let bucket = TRANSCODED_BUCKET;
    let key = fileKey;

    // Handle different quality requests
    if (quality !== 'original') {
        const baseName = fileKey.replace(/\.[^/.]+$/, '');
        const extension = getQualityExtension(quality);
        key = `${baseName}_${quality}.${extension}`;
    }

    // Check if file exists
    try {
        await s3.headObject({ Bucket: bucket, Key: key }).promise();
    } catch (error) {
        if (error.code === 'NotFound') {
            // Fallback to original file in raw bucket
            bucket = RAW_BUCKET;
            key = fileKey;
        } else {
            throw error;
        }
    }

    // Generate presigned URL based on configuration
    if (ENABLE_SIGNED_URLS === 'true' && CLOUDFRONT_DOMAIN) {
        return await generateCloudFrontSignedUrl(key, userId);
    } else {
        return await generateS3SignedUrl(bucket, key);
    }
}

/**
 * Generate CloudFront signed URL
 */
async function generateCloudFrontSignedUrl(key, userId) {
    // Note: This is a simplified implementation
    // In production, you would use CloudFront signed URLs with proper key pairs
    const url = `https://${CLOUDFRONT_DOMAIN}/${key}`;
    
    return {
        downloadUrl: url,
        expiresAt: new Date(Date.now() + URL_EXPIRATION_SECONDS * 1000).toISOString(),
        type: 'cloudfront_signed'
    };
}

/**
 * Generate S3 signed URL
 */
async function generateS3SignedUrl(bucket, key) {
    const params = {
        Bucket: bucket,
        Key: key,
        Expires: URL_EXPIRATION_SECONDS
    };

    const downloadUrl = await s3.getSignedUrlPromise('getObject', params);

    return {
        downloadUrl: downloadUrl,
        expiresAt: new Date(Date.now() + URL_EXPIRATION_SECONDS * 1000).toISOString(),
        type: 's3_signed'
    };
}

/**
 * Validate upload request parameters
 */
function validateUploadRequest({ fileName, fileSize, contentType }) {
    if (!fileName) {
        throw new Error('fileName is required');
    }

    if (!fileSize || fileSize <= 0) {
        throw new Error('Valid fileSize is required');
    }

    if (fileSize > MAX_FILE_SIZE_BYTES) {
        throw new Error(`File size ${Math.round(fileSize / 1024 / 1024)}MB exceeds maximum allowed size of ${MAX_FILE_SIZE_MB}MB`);
    }

    const fileExtension = fileName.split('.').pop().toLowerCase();
    const allowedFormats = ALLOWED_FORMATS.split(',');

    if (!allowedFormats.includes(fileExtension)) {
        throw new Error(`File format '${fileExtension}' is not allowed. Allowed formats: ${allowedFormats.join(', ')}`);
    }

    if (contentType && !contentType.startsWith('video/')) {
        console.warn(`Non-video content type detected: ${contentType}`);
    }
}

/**
 * Get file extension for quality level
 */
function getQualityExtension(quality) {
    const extensionMap = {
        '1080p': 'mp4',
        '720p': 'mp4',
        '480p': 'mp4',
        'hls': 'm3u8'
    };

    return extensionMap[quality] || 'mp4';
}

/**
 * Utility function for structured logging
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