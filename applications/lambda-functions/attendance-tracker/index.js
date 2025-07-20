/**
 * AWS Lambda Function: Attendance Tracker
 * 
 * Handles attendance check-in/check-out operations with:
 * - Geolocation validation
 * - QR code generation and verification
 * - Real-time attendance status tracking
 * - Integration with Cognito for user authentication
 */

const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');
const QRCode = require('qrcode');
const Joi = require('joi');
const moment = require('moment');
const geolib = require('geolib');
const jwt = require('jsonwebtoken');

// Initialize AWS services
const dynamodb = new AWS.DynamoDB.DocumentClient();
const sns = new AWS.SNS();
const cognito = new AWS.CognitoIdentityServiceProvider();

// Environment variables
const ATTENDANCE_TABLE_NAME = process.env.ATTENDANCE_TABLE_NAME;
const CLASSES_TABLE_NAME = process.env.CLASSES_TABLE_NAME;
const USER_POOL_ID = process.env.USER_POOL_ID;
const ENVIRONMENT = process.env.ENVIRONMENT;
const SESSION_DURATION_MINUTES = parseInt(process.env.SESSION_DURATION_MINUTES) || 180;
const GEOLOCATION_RADIUS_METERS = parseInt(process.env.GEOLOCATION_RADIUS_METERS) || 100;
const ENABLE_GEOLOCATION_VALIDATION = process.env.ENABLE_GEOLOCATION_VALIDATION === 'true';
const QR_CODE_EXPIRY_MINUTES = parseInt(process.env.QR_CODE_EXPIRY_MINUTES) || 15;
const GRACE_PERIOD_MINUTES = parseInt(process.env.GRACE_PERIOD_MINUTES) || 10;
const NOTIFICATION_TOPIC_ARN = process.env.NOTIFICATION_TOPIC_ARN;
const ENABLE_NOTIFICATIONS = process.env.ENABLE_NOTIFICATIONS === 'true';

// Validation schemas
const checkInSchema = Joi.object({
  classId: Joi.string().required(),
  qrCode: Joi.string().optional(),
  location: Joi.object({
    latitude: Joi.number().min(-90).max(90).required(),
    longitude: Joi.number().min(-180).max(180).required()
  }).optional(),
  timestamp: Joi.string().isoDate().optional()
});

const checkOutSchema = Joi.object({
  attendanceId: Joi.string().required(),
  location: Joi.object({
    latitude: Joi.number().min(-90).max(90).required(),
    longitude: Joi.number().min(-180).max(180).required()
  }).optional(),
  timestamp: Joi.string().isoDate().optional()
});

/**
 * Main Lambda handler
 */
exports.handler = async (event) => {
  console.log('Attendance Tracker Event:', JSON.stringify(event, null, 2));

  try {
    // Extract user information from JWT token
    const userInfo = await extractUserFromToken(event);
    
    // Route based on HTTP method and path
    const { httpMethod, path, pathParameters, queryStringParameters, body } = event;
    
    switch (httpMethod) {
      case 'POST':
        if (path.includes('/check-in')) {
          return await handleCheckIn(userInfo, JSON.parse(body || '{}'));
        } else if (path.includes('/check-out')) {
          return await handleCheckOut(userInfo, JSON.parse(body || '{}'));
        } else if (path.includes('/qr')) {
          return await handleGenerateQR(userInfo, pathParameters);
        }
        break;
        
      case 'GET':
        if (path.includes('/status/')) {
          return await handleGetStatus(userInfo, pathParameters);
        } else if (path.includes('/history/')) {
          return await handleGetHistory(userInfo, pathParameters, queryStringParameters);
        }
        break;
    }

    return createResponse(400, { error: 'Invalid request' });

  } catch (error) {
    console.error('Error processing attendance request:', error);
    return createResponse(500, { 
      error: 'Internal server error',
      message: error.message 
    });
  }
};

/**
 * Handle check-in request
 */
async function handleCheckIn(userInfo, requestBody) {
  // Validate request
  const { error, value } = checkInSchema.validate(requestBody);
  if (error) {
    return createResponse(400, { error: error.details[0].message });
  }

  const { classId, qrCode, location, timestamp } = value;
  const checkInTime = timestamp ? moment(timestamp) : moment();

  try {
    // Get class information
    const classInfo = await getClassInfo(classId);
    if (!classInfo) {
      return createResponse(404, { error: 'Class not found' });
    }

    // Validate QR code if provided
    if (qrCode && !await validateQRCode(qrCode, classId)) {
      return createResponse(400, { error: 'Invalid or expired QR code' });
    }

    // Validate geolocation if enabled and provided
    if (ENABLE_GEOLOCATION_VALIDATION && location && classInfo.location) {
      const distance = geolib.getDistance(
        { latitude: location.latitude, longitude: location.longitude },
        { latitude: classInfo.location.latitude, longitude: classInfo.location.longitude }
      );

      if (distance > GEOLOCATION_RADIUS_METERS) {
        return createResponse(400, { 
          error: 'Location validation failed',
          distance: distance,
          allowedRadius: GEOLOCATION_RADIUS_METERS
        });
      }
    }

    // Check if user is already checked in for this class
    const existingAttendance = await getExistingAttendance(userInfo.userId, classId, checkInTime.format('YYYY-MM-DD'));
    if (existingAttendance && existingAttendance.status === 'checked_in') {
      return createResponse(400, { error: 'Already checked in for this class' });
    }

    // Determine attendance status based on timing
    const classStartTime = moment(classInfo.startTime);
    const graceEndTime = classStartTime.clone().add(GRACE_PERIOD_MINUTES, 'minutes');
    
    let status = 'present';
    if (checkInTime.isAfter(graceEndTime)) {
      status = 'late';
    }

    // Create attendance record
    const attendanceId = uuidv4();
    const attendanceRecord = {
      attendance_id: attendanceId,
      timestamp: checkInTime.toISOString(),
      user_id: userInfo.userId,
      class_id: classId,
      date: checkInTime.format('YYYY-MM-DD'),
      status: 'checked_in',
      attendance_status: status,
      check_in_time: checkInTime.toISOString(),
      location: location || null,
      qr_code_used: !!qrCode,
      created_at: moment().toISOString(),
      ttl: moment().add(1, 'year').unix(), // TTL for cleanup
      user_name: userInfo.name || userInfo.email,
      class_name: classInfo.name,
      course_code: classInfo.courseCode,
      instructor_id: classInfo.instructorId
    };

    // Save to DynamoDB
    await dynamodb.put({
      TableName: ATTENDANCE_TABLE_NAME,
      Item: attendanceRecord
    }).promise();

    // Send notification if enabled
    if (ENABLE_NOTIFICATIONS && NOTIFICATION_TOPIC_ARN) {
      await sendNotification({
        type: 'check_in',
        userId: userInfo.userId,
        userName: userInfo.name || userInfo.email,
        classId: classId,
        className: classInfo.name,
        status: status,
        timestamp: checkInTime.toISOString()
      });
    }

    return createResponse(200, {
      success: true,
      attendanceId: attendanceId,
      status: status,
      checkInTime: checkInTime.toISOString(),
      message: `Successfully checked in${status === 'late' ? ' (marked as late)' : ''}`
    });

  } catch (error) {
    console.error('Error during check-in:', error);
    throw error;
  }
}

/**
 * Handle check-out request
 */
async function handleCheckOut(userInfo, requestBody) {
  // Validate request
  const { error, value } = checkOutSchema.validate(requestBody);
  if (error) {
    return createResponse(400, { error: error.details[0].message });
  }

  const { attendanceId, location, timestamp } = value;
  const checkOutTime = timestamp ? moment(timestamp) : moment();

  try {
    // Get attendance record
    const attendanceRecord = await getAttendanceRecord(attendanceId);
    if (!attendanceRecord) {
      return createResponse(404, { error: 'Attendance record not found' });
    }

    // Verify user owns this attendance record
    if (attendanceRecord.user_id !== userInfo.userId) {
      return createResponse(403, { error: 'Unauthorized to modify this attendance record' });
    }

    // Check if already checked out
    if (attendanceRecord.status === 'checked_out') {
      return createResponse(400, { error: 'Already checked out' });
    }

    // Calculate session duration
    const checkInTime = moment(attendanceRecord.check_in_time);
    const sessionDuration = checkOutTime.diff(checkInTime, 'minutes');

    // Update attendance record
    const updateParams = {
      TableName: ATTENDANCE_TABLE_NAME,
      Key: {
        attendance_id: attendanceId,
        timestamp: attendanceRecord.timestamp
      },
      UpdateExpression: 'SET #status = :status, check_out_time = :checkOutTime, session_duration_minutes = :duration, updated_at = :updatedAt',
      ExpressionAttributeNames: {
        '#status': 'status'
      },
      ExpressionAttributeValues: {
        ':status': 'checked_out',
        ':checkOutTime': checkOutTime.toISOString(),
        ':duration': sessionDuration,
        ':updatedAt': moment().toISOString()
      }
    };

    if (location) {
      updateParams.UpdateExpression += ', check_out_location = :location';
      updateParams.ExpressionAttributeValues[':location'] = location;
    }

    await dynamodb.update(updateParams).promise();

    // Send notification if enabled
    if (ENABLE_NOTIFICATIONS && NOTIFICATION_TOPIC_ARN) {
      await sendNotification({
        type: 'check_out',
        userId: userInfo.userId,
        userName: userInfo.name || userInfo.email,
        classId: attendanceRecord.class_id,
        className: attendanceRecord.class_name,
        sessionDuration: sessionDuration,
        timestamp: checkOutTime.toISOString()
      });
    }

    return createResponse(200, {
      success: true,
      attendanceId: attendanceId,
      checkOutTime: checkOutTime.toISOString(),
      sessionDuration: sessionDuration,
      message: 'Successfully checked out'
    });

  } catch (error) {
    console.error('Error during check-out:', error);
    throw error;
  }
}

/**
 * Generate QR code for class attendance
 */
async function handleGenerateQR(userInfo, pathParameters) {
  const { classId } = pathParameters;

  try {
    // Verify user has permission to generate QR codes (instructor/admin)
    if (!userInfo.groups || (!userInfo.groups.includes('teachers') && !userInfo.groups.includes('admins'))) {
      return createResponse(403, { error: 'Insufficient permissions to generate QR codes' });
    }

    // Get class information
    const classInfo = await getClassInfo(classId);
    if (!classInfo) {
      return createResponse(404, { error: 'Class not found' });
    }

    // Verify instructor owns this class
    if (classInfo.instructorId !== userInfo.userId && !userInfo.groups.includes('admins')) {
      return createResponse(403, { error: 'Unauthorized to generate QR code for this class' });
    }

    // Generate QR code data
    const qrData = {
      classId: classId,
      timestamp: moment().toISOString(),
      expiresAt: moment().add(QR_CODE_EXPIRY_MINUTES, 'minutes').toISOString(),
      signature: generateQRSignature(classId, moment().toISOString())
    };

    // Generate QR code image
    const qrCodeDataURL = await QRCode.toDataURL(JSON.stringify(qrData), {
      errorCorrectionLevel: 'M',
      type: 'image/png',
      quality: 0.92,
      margin: 1,
      color: {
        dark: '#000000',
        light: '#FFFFFF'
      }
    });

    return createResponse(200, {
      success: true,
      qrCode: qrCodeDataURL,
      qrData: qrData,
      expiresAt: qrData.expiresAt,
      validFor: QR_CODE_EXPIRY_MINUTES
    });

  } catch (error) {
    console.error('Error generating QR code:', error);
    throw error;
  }
}

/**
 * Get attendance status for a user
 */
async function handleGetStatus(userInfo, pathParameters) {
  const { userId } = pathParameters;

  // Users can only view their own status unless they're admin/teacher
  if (userId !== userInfo.userId && !userInfo.groups?.includes('admins') && !userInfo.groups?.includes('teachers')) {
    return createResponse(403, { error: 'Unauthorized to view this user\'s status' });
  }

  try {
    const today = moment().format('YYYY-MM-DD');
    
    // Get today's attendance records
    const params = {
      TableName: ATTENDANCE_TABLE_NAME,
      IndexName: 'UserDateIndex',
      KeyConditionExpression: 'user_id = :userId AND #date = :date',
      ExpressionAttributeNames: {
        '#date': 'date'
      },
      ExpressionAttributeValues: {
        ':userId': userId,
        ':date': today
      }
    };

    const result = await dynamodb.query(params).promise();
    
    return createResponse(200, {
      success: true,
      userId: userId,
      date: today,
      attendanceRecords: result.Items,
      totalSessions: result.Items.length,
      checkedInSessions: result.Items.filter(item => item.status === 'checked_in').length
    });

  } catch (error) {
    console.error('Error getting attendance status:', error);
    throw error;
  }
}

/**
 * Get attendance history for a user
 */
async function handleGetHistory(userInfo, pathParameters, queryStringParameters) {
  const { userId } = pathParameters;
  const { from, to, limit = '50' } = queryStringParameters || {};

  // Users can only view their own history unless they're admin/teacher
  if (userId !== userInfo.userId && !userInfo.groups?.includes('admins') && !userInfo.groups?.includes('teachers')) {
    return createResponse(403, { error: 'Unauthorized to view this user\'s history' });
  }

  try {
    const fromDate = from ? moment(from).format('YYYY-MM-DD') : moment().subtract(30, 'days').format('YYYY-MM-DD');
    const toDate = to ? moment(to).format('YYYY-MM-DD') : moment().format('YYYY-MM-DD');

    const params = {
      TableName: ATTENDANCE_TABLE_NAME,
      IndexName: 'UserDateIndex',
      KeyConditionExpression: 'user_id = :userId AND #date BETWEEN :fromDate AND :toDate',
      ExpressionAttributeNames: {
        '#date': 'date'
      },
      ExpressionAttributeValues: {
        ':userId': userId,
        ':fromDate': fromDate,
        ':toDate': toDate
      },
      Limit: parseInt(limit),
      ScanIndexForward: false // Most recent first
    };

    const result = await dynamodb.query(params).promise();
    
    // Calculate summary statistics
    const summary = {
      totalSessions: result.Items.length,
      presentCount: result.Items.filter(item => item.attendance_status === 'present').length,
      lateCount: result.Items.filter(item => item.attendance_status === 'late').length,
      absentCount: result.Items.filter(item => item.attendance_status === 'absent').length,
      averageSessionDuration: result.Items
        .filter(item => item.session_duration_minutes)
        .reduce((sum, item) => sum + item.session_duration_minutes, 0) / 
        result.Items.filter(item => item.session_duration_minutes).length || 0
    };

    return createResponse(200, {
      success: true,
      userId: userId,
      dateRange: { from: fromDate, to: toDate },
      attendanceHistory: result.Items,
      summary: summary,
      hasMore: !!result.LastEvaluatedKey
    });

  } catch (error) {
    console.error('Error getting attendance history:', error);
    throw error;
  }
}

/**
 * Helper Functions
 */

async function extractUserFromToken(event) {
  try {
    const authHeader = event.headers?.Authorization || event.headers?.authorization;
    if (!authHeader) {
      throw new Error('No authorization header found');
    }

    const token = authHeader.replace('Bearer ', '');
    const decoded = jwt.decode(token, { complete: true });
    
    if (!decoded) {
      throw new Error('Invalid token format');
    }

    return {
      userId: decoded.payload.sub,
      email: decoded.payload.email,
      name: decoded.payload.name,
      groups: decoded.payload['cognito:groups'] || []
    };
  } catch (error) {
    console.error('Error extracting user from token:', error);
    throw new Error('Invalid authentication token');
  }
}

async function getClassInfo(classId) {
  try {
    const params = {
      TableName: CLASSES_TABLE_NAME,
      Key: { class_id: classId }
    };

    const result = await dynamodb.get(params).promise();
    return result.Item;
  } catch (error) {
    console.error('Error getting class info:', error);
    return null;
  }
}

async function validateQRCode(qrCode, classId) {
  try {
    const qrData = JSON.parse(qrCode);
    
    // Check if QR code is for the correct class
    if (qrData.classId !== classId) {
      return false;
    }

    // Check if QR code has expired
    if (moment().isAfter(moment(qrData.expiresAt))) {
      return false;
    }

    // Verify signature
    const expectedSignature = generateQRSignature(qrData.classId, qrData.timestamp);
    return qrData.signature === expectedSignature;
  } catch (error) {
    console.error('Error validating QR code:', error);
    return false;
  }
}

function generateQRSignature(classId, timestamp) {
  // Simple signature generation - in production, use proper HMAC
  const crypto = require('crypto');
  const secret = `${ENVIRONMENT}-qr-secret`;
  return crypto.createHmac('sha256', secret).update(`${classId}-${timestamp}`).digest('hex');
}

async function getExistingAttendance(userId, classId, date) {
  try {
    const params = {
      TableName: ATTENDANCE_TABLE_NAME,
      IndexName: 'UserDateIndex',
      KeyConditionExpression: 'user_id = :userId AND #date = :date',
      FilterExpression: 'class_id = :classId',
      ExpressionAttributeNames: {
        '#date': 'date'
      },
      ExpressionAttributeValues: {
        ':userId': userId,
        ':date': date,
        ':classId': classId
      }
    };

    const result = await dynamodb.query(params).promise();
    return result.Items.length > 0 ? result.Items[0] : null;
  } catch (error) {
    console.error('Error getting existing attendance:', error);
    return null;
  }
}

async function getAttendanceRecord(attendanceId) {
  try {
    const params = {
      TableName: ATTENDANCE_TABLE_NAME,
      KeyConditionExpression: 'attendance_id = :attendanceId',
      ExpressionAttributeValues: {
        ':attendanceId': attendanceId
      }
    };

    const result = await dynamodb.query(params).promise();
    return result.Items.length > 0 ? result.Items[0] : null;
  } catch (error) {
    console.error('Error getting attendance record:', error);
    return null;
  }
}

async function sendNotification(notificationData) {
  if (!ENABLE_NOTIFICATIONS || !NOTIFICATION_TOPIC_ARN) {
    return;
  }

  try {
    const message = {
      type: 'attendance',
      data: notificationData,
      timestamp: moment().toISOString()
    };

    await sns.publish({
      TopicArn: NOTIFICATION_TOPIC_ARN,
      Message: JSON.stringify(message),
      Subject: `Attendance ${notificationData.type.replace('_', ' ')} - ${notificationData.className}`
    }).promise();
  } catch (error) {
    console.error('Error sending notification:', error);
    // Don't throw - notifications are not critical
  }
}

function createResponse(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
    },
    body: JSON.stringify(body)
  };
}