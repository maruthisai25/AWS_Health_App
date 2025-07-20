/**
 * AWS Lambda Function: Attendance Reporter
 * 
 * Generates attendance reports and analytics with:
 * - CSV export functionality
 * - Comprehensive analytics and insights
 * - Scheduled report generation
 * - S3 storage for reports
 */

const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');
const moment = require('moment');
const { Parser } = require('json2csv');
const _ = require('lodash');
const jwt = require('jsonwebtoken');

// Initialize AWS services
const dynamodb = new AWS.DynamoDB.DocumentClient();
const s3 = new AWS.S3();
const sns = new AWS.SNS();
const cognito = new AWS.CognitoIdentityServiceProvider();

// Environment variables
const ATTENDANCE_TABLE_NAME = process.env.ATTENDANCE_TABLE_NAME;
const CLASSES_TABLE_NAME = process.env.CLASSES_TABLE_NAME;
const USER_POOL_ID = process.env.USER_POOL_ID;
const ENVIRONMENT = process.env.ENVIRONMENT;
const ENABLE_CSV_EXPORT = process.env.ENABLE_CSV_EXPORT === 'true';
const REPORT_S3_BUCKET = process.env.REPORT_S3_BUCKET;
const ENABLE_ANALYTICS = process.env.ENABLE_ANALYTICS === 'true';
const NOTIFICATION_TOPIC_ARN = process.env.NOTIFICATION_TOPIC_ARN;

/**
 * Main Lambda handler
 */
exports.handler = async (event) => {
  console.log('Attendance Reporter Event:', JSON.stringify(event, null, 2));

  try {
    // Handle scheduled events (EventBridge)
    if (event.source === 'aws.events') {
      return await handleScheduledReport(event);
    }

    // Handle API Gateway requests
    const userInfo = await extractUserFromToken(event);
    const { httpMethod, path, queryStringParameters } = event;

    if (httpMethod === 'GET') {
      if (path.includes('/reports')) {
        return await handleGetReports(userInfo, queryStringParameters);
      } else if (path.includes('/analytics')) {
        return await handleGetAnalytics(userInfo, queryStringParameters);
      }
    }

    return createResponse(400, { error: 'Invalid request' });

  } catch (error) {
    console.error('Error processing attendance report request:', error);
    return createResponse(500, { 
      error: 'Internal server error',
      message: error.message 
    });
  }
};

/**
 * Handle scheduled report generation
 */
async function handleScheduledReport(event) {
  console.log('Processing scheduled report:', event);

  try {
    const reportType = event.reportType || 'daily';
    const reportDate = moment().format('YYYY-MM-DD');

    // Generate daily attendance report
    const report = await generateDailyReport(reportDate);

    // Save report to S3 if enabled
    if (ENABLE_CSV_EXPORT && REPORT_S3_BUCKET) {
      const reportKey = `attendance-reports/${ENVIRONMENT}/${reportType}/${reportDate}.json`;
      await s3.putObject({
        Bucket: REPORT_S3_BUCKET,
        Key: reportKey,
        Body: JSON.stringify(report, null, 2),
        ContentType: 'application/json'
      }).promise();

      console.log(`Report saved to S3: ${reportKey}`);
    }

    // Send notification if enabled
    if (NOTIFICATION_TOPIC_ARN) {
      await sns.publish({
        TopicArn: NOTIFICATION_TOPIC_ARN,
        Message: JSON.stringify({
          type: 'scheduled_report',
          reportType: reportType,
          date: reportDate,
          summary: report.summary
        }),
        Subject: `Daily Attendance Report - ${reportDate}`
      }).promise();
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        success: true,
        reportType: reportType,
        date: reportDate,
        summary: report.summary
      })
    };

  } catch (error) {
    console.error('Error generating scheduled report:', error);
    throw error;
  }
}

/**
 * Handle get reports request
 */
async function handleGetReports(userInfo, queryStringParameters) {
  const {
    type = 'summary',
    from,
    to,
    format = 'json',
    classId,
    courseCode
  } = queryStringParameters || {};

  try {
    // Verify user has permission to view reports
    if (!userInfo.groups?.includes('teachers') && !userInfo.groups?.includes('admins')) {
      return createResponse(403, { error: 'Insufficient permissions to view reports' });
    }

    const fromDate = from ? moment(from).format('YYYY-MM-DD') : moment().subtract(7, 'days').format('YYYY-MM-DD');
    const toDate = to ? moment(to).format('YYYY-MM-DD') : moment().format('YYYY-MM-DD');

    let report;
    switch (type) {
      case 'summary':
        report = await generateSummaryReport(fromDate, toDate, { classId, courseCode });
        break;
      case 'detailed':
        report = await generateDetailedReport(fromDate, toDate, { classId, courseCode });
        break;
      case 'class':
        if (!classId) {
          return createResponse(400, { error: 'classId is required for class reports' });
        }
        report = await generateClassReport(classId, fromDate, toDate);
        break;
      case 'student':
        report = await generateStudentReport(fromDate, toDate, { classId, courseCode });
        break;
      default:
        return createResponse(400, { error: 'Invalid report type' });
    }

    // Return CSV format if requested
    if (format === 'csv' && ENABLE_CSV_EXPORT) {
      const csvData = await convertToCSV(report, type);
      return {
        statusCode: 200,
        headers: {
          'Content-Type': 'text/csv',
          'Content-Disposition': `attachment; filename="attendance-report-${type}-${fromDate}-to-${toDate}.csv"`,
          'Access-Control-Allow-Origin': '*'
        },
        body: csvData
      };
    }

    return createResponse(200, {
      success: true,
      reportType: type,
      dateRange: { from: fromDate, to: toDate },
      filters: { classId, courseCode },
      report: report
    });

  } catch (error) {
    console.error('Error generating report:', error);
    throw error;
  }
}

/**
 * Handle get analytics request
 */
async function handleGetAnalytics(userInfo, queryStringParameters) {
  if (!ENABLE_ANALYTICS) {
    return createResponse(400, { error: 'Analytics not enabled' });
  }

  const {
    period = 'week',
    classId,
    courseCode,
    userId
  } = queryStringParameters || {};

  try {
    // Verify user has permission to view analytics
    if (!userInfo.groups?.includes('teachers') && !userInfo.groups?.includes('admins')) {
      // Students can only view their own analytics
      if (!userId || userId !== userInfo.userId) {
        return createResponse(403, { error: 'Insufficient permissions to view analytics' });
      }
    }

    const analytics = await generateAnalytics(period, { classId, courseCode, userId });

    return createResponse(200, {
      success: true,
      period: period,
      filters: { classId, courseCode, userId },
      analytics: analytics
    });

  } catch (error) {
    console.error('Error generating analytics:', error);
    throw error;
  }
}

/**
 * Report Generation Functions
 */

async function generateDailyReport(date) {
  const params = {
    TableName: ATTENDANCE_TABLE_NAME,
    IndexName: 'StatusDateIndex',
    KeyConditionExpression: '#status = :status AND #date = :date',
    ExpressionAttributeNames: {
      '#status': 'status',
      '#date': 'date'
    },
    ExpressionAttributeValues: {
      ':status': 'checked_in',
      ':date': date
    }
  };

  const result = await dynamodb.query(params).promise();
  const attendanceRecords = result.Items;

  // Group by class
  const classSummary = _.groupBy(attendanceRecords, 'class_id');
  const classReports = {};

  for (const [classId, records] of Object.entries(classSummary)) {
    const classInfo = await getClassInfo(classId);
    classReports[classId] = {
      className: classInfo?.name || 'Unknown Class',
      courseCode: classInfo?.courseCode || 'Unknown',
      totalAttendees: records.length,
      presentCount: records.filter(r => r.attendance_status === 'present').length,
      lateCount: records.filter(r => r.attendance_status === 'late').length,
      attendanceRate: records.length > 0 ? (records.filter(r => r.attendance_status === 'present').length / records.length * 100).toFixed(2) : 0
    };
  }

  return {
    date: date,
    summary: {
      totalClasses: Object.keys(classReports).length,
      totalAttendees: attendanceRecords.length,
      averageAttendanceRate: Object.values(classReports).reduce((sum, cls) => sum + parseFloat(cls.attendanceRate), 0) / Object.keys(classReports).length || 0
    },
    classSummary: classReports,
    generatedAt: moment().toISOString()
  };
}

async function generateSummaryReport(fromDate, toDate, filters = {}) {
  const params = {
    TableName: ATTENDANCE_TABLE_NAME,
    FilterExpression: '#date BETWEEN :fromDate AND :toDate',
    ExpressionAttributeNames: {
      '#date': 'date'
    },
    ExpressionAttributeValues: {
      ':fromDate': fromDate,
      ':toDate': toDate
    }
  };

  // Add filters
  if (filters.classId) {
    params.FilterExpression += ' AND class_id = :classId';
    params.ExpressionAttributeValues[':classId'] = filters.classId;
  }

  if (filters.courseCode) {
    params.FilterExpression += ' AND course_code = :courseCode';
    params.ExpressionAttributeValues[':courseCode'] = filters.courseCode;
  }

  const result = await dynamodb.scan(params).promise();
  const attendanceRecords = result.Items;

  // Calculate summary statistics
  const summary = {
    totalRecords: attendanceRecords.length,
    uniqueStudents: new Set(attendanceRecords.map(r => r.user_id)).size,
    uniqueClasses: new Set(attendanceRecords.map(r => r.class_id)).size,
    presentCount: attendanceRecords.filter(r => r.attendance_status === 'present').length,
    lateCount: attendanceRecords.filter(r => r.attendance_status === 'late').length,
    absentCount: attendanceRecords.filter(r => r.attendance_status === 'absent').length,
    averageSessionDuration: attendanceRecords
      .filter(r => r.session_duration_minutes)
      .reduce((sum, r) => sum + r.session_duration_minutes, 0) / 
      attendanceRecords.filter(r => r.session_duration_minutes).length || 0
  };

  // Daily breakdown
  const dailyBreakdown = _.groupBy(attendanceRecords, 'date');
  const dailyStats = {};

  for (const [date, records] of Object.entries(dailyBreakdown)) {
    dailyStats[date] = {
      totalAttendees: records.length,
      presentCount: records.filter(r => r.attendance_status === 'present').length,
      lateCount: records.filter(r => r.attendance_status === 'late').length,
      attendanceRate: records.length > 0 ? (records.filter(r => r.attendance_status === 'present').length / records.length * 100).toFixed(2) : 0
    };
  }

  return {
    dateRange: { from: fromDate, to: toDate },
    summary: summary,
    dailyBreakdown: dailyStats,
    generatedAt: moment().toISOString()
  };
}

async function generateDetailedReport(fromDate, toDate, filters = {}) {
  const params = {
    TableName: ATTENDANCE_TABLE_NAME,
    FilterExpression: '#date BETWEEN :fromDate AND :toDate',
    ExpressionAttributeNames: {
      '#date': 'date'
    },
    ExpressionAttributeValues: {
      ':fromDate': fromDate,
      ':toDate': toDate
    }
  };

  // Add filters
  if (filters.classId) {
    params.FilterExpression += ' AND class_id = :classId';
    params.ExpressionAttributeValues[':classId'] = filters.classId;
  }

  if (filters.courseCode) {
    params.FilterExpression += ' AND course_code = :courseCode';
    params.ExpressionAttributeValues[':courseCode'] = filters.courseCode;
  }

  const result = await dynamodb.scan(params).promise();
  const attendanceRecords = result.Items;

  // Sort by date and time
  attendanceRecords.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

  return {
    dateRange: { from: fromDate, to: toDate },
    totalRecords: attendanceRecords.length,
    attendanceRecords: attendanceRecords.map(record => ({
      attendanceId: record.attendance_id,
      userId: record.user_id,
      userName: record.user_name,
      classId: record.class_id,
      className: record.class_name,
      courseCode: record.course_code,
      date: record.date,
      checkInTime: record.check_in_time,
      checkOutTime: record.check_out_time,
      status: record.attendance_status,
      sessionDuration: record.session_duration_minutes,
      qrCodeUsed: record.qr_code_used,
      location: record.location
    })),
    generatedAt: moment().toISOString()
  };
}

async function generateClassReport(classId, fromDate, toDate) {
  const classInfo = await getClassInfo(classId);
  if (!classInfo) {
    throw new Error('Class not found');
  }

  const params = {
    TableName: ATTENDANCE_TABLE_NAME,
    IndexName: 'ClassDateIndex',
    KeyConditionExpression: 'class_id = :classId AND #date BETWEEN :fromDate AND :toDate',
    ExpressionAttributeNames: {
      '#date': 'date'
    },
    ExpressionAttributeValues: {
      ':classId': classId,
      ':fromDate': fromDate,
      ':toDate': toDate
    }
  };

  const result = await dynamodb.query(params).promise();
  const attendanceRecords = result.Items;

  // Student attendance summary
  const studentSummary = _.groupBy(attendanceRecords, 'user_id');
  const studentStats = {};

  for (const [userId, records] of Object.entries(studentSummary)) {
    const presentCount = records.filter(r => r.attendance_status === 'present').length;
    const lateCount = records.filter(r => r.attendance_status === 'late').length;
    const totalSessions = records.length;

    studentStats[userId] = {
      userName: records[0].user_name,
      totalSessions: totalSessions,
      presentCount: presentCount,
      lateCount: lateCount,
      attendanceRate: totalSessions > 0 ? ((presentCount + lateCount) / totalSessions * 100).toFixed(2) : 0,
      averageSessionDuration: records
        .filter(r => r.session_duration_minutes)
        .reduce((sum, r) => sum + r.session_duration_minutes, 0) / 
        records.filter(r => r.session_duration_minutes).length || 0
    };
  }

  return {
    classInfo: {
      classId: classId,
      className: classInfo.name,
      courseCode: classInfo.courseCode,
      instructorId: classInfo.instructorId
    },
    dateRange: { from: fromDate, to: toDate },
    summary: {
      totalSessions: attendanceRecords.length,
      uniqueStudents: Object.keys(studentStats).length,
      averageAttendanceRate: Object.values(studentStats).reduce((sum, student) => sum + parseFloat(student.attendanceRate), 0) / Object.keys(studentStats).length || 0
    },
    studentSummary: studentStats,
    generatedAt: moment().toISOString()
  };
}

async function generateStudentReport(fromDate, toDate, filters = {}) {
  const params = {
    TableName: ATTENDANCE_TABLE_NAME,
    FilterExpression: '#date BETWEEN :fromDate AND :toDate',
    ExpressionAttributeNames: {
      '#date': 'date'
    },
    ExpressionAttributeValues: {
      ':fromDate': fromDate,
      ':toDate': toDate
    }
  };

  // Add filters
  if (filters.classId) {
    params.FilterExpression += ' AND class_id = :classId';
    params.ExpressionAttributeValues[':classId'] = filters.classId;
  }

  if (filters.courseCode) {
    params.FilterExpression += ' AND course_code = :courseCode';
    params.ExpressionAttributeValues[':courseCode'] = filters.courseCode;
  }

  const result = await dynamodb.scan(params).promise();
  const attendanceRecords = result.Items;

  // Group by student
  const studentSummary = _.groupBy(attendanceRecords, 'user_id');
  const studentReports = {};

  for (const [userId, records] of Object.entries(studentSummary)) {
    const presentCount = records.filter(r => r.attendance_status === 'present').length;
    const lateCount = records.filter(r => r.attendance_status === 'late').length;
    const totalSessions = records.length;

    studentReports[userId] = {
      userName: records[0].user_name,
      totalSessions: totalSessions,
      presentCount: presentCount,
      lateCount: lateCount,
      attendanceRate: totalSessions > 0 ? ((presentCount + lateCount) / totalSessions * 100).toFixed(2) : 0,
      averageSessionDuration: records
        .filter(r => r.session_duration_minutes)
        .reduce((sum, r) => sum + r.session_duration_minutes, 0) / 
        records.filter(r => r.session_duration_minutes).length || 0,
      classesByDate: _.groupBy(records, 'date')
    };
  }

  return {
    dateRange: { from: fromDate, to: toDate },
    totalStudents: Object.keys(studentReports).length,
    studentReports: studentReports,
    generatedAt: moment().toISOString()
  };
}

async function generateAnalytics(period, filters = {}) {
  const endDate = moment();
  let startDate;

  switch (period) {
    case 'day':
      startDate = moment().subtract(1, 'day');
      break;
    case 'week':
      startDate = moment().subtract(1, 'week');
      break;
    case 'month':
      startDate = moment().subtract(1, 'month');
      break;
    case 'quarter':
      startDate = moment().subtract(3, 'months');
      break;
    default:
      startDate = moment().subtract(1, 'week');
  }

  const params = {
    TableName: ATTENDANCE_TABLE_NAME,
    FilterExpression: '#date BETWEEN :fromDate AND :toDate',
    ExpressionAttributeNames: {
      '#date': 'date'
    },
    ExpressionAttributeValues: {
      ':fromDate': startDate.format('YYYY-MM-DD'),
      ':toDate': endDate.format('YYYY-MM-DD')
    }
  };

  // Add filters
  if (filters.classId) {
    params.FilterExpression += ' AND class_id = :classId';
    params.ExpressionAttributeValues[':classId'] = filters.classId;
  }

  if (filters.courseCode) {
    params.FilterExpression += ' AND course_code = :courseCode';
    params.ExpressionAttributeValues[':courseCode'] = filters.courseCode;
  }

  if (filters.userId) {
    params.FilterExpression += ' AND user_id = :userId';
    params.ExpressionAttributeValues[':userId'] = filters.userId;
  }

  const result = await dynamodb.scan(params).promise();
  const attendanceRecords = result.Items;

  // Calculate analytics
  const analytics = {
    period: period,
    dateRange: {
      from: startDate.format('YYYY-MM-DD'),
      to: endDate.format('YYYY-MM-DD')
    },
    overview: {
      totalRecords: attendanceRecords.length,
      uniqueStudents: new Set(attendanceRecords.map(r => r.user_id)).size,
      uniqueClasses: new Set(attendanceRecords.map(r => r.class_id)).size,
      averageAttendanceRate: attendanceRecords.length > 0 ? 
        (attendanceRecords.filter(r => r.attendance_status === 'present').length / attendanceRecords.length * 100).toFixed(2) : 0
    },
    trends: {
      dailyAttendance: generateDailyTrend(attendanceRecords),
      attendanceByStatus: {
        present: attendanceRecords.filter(r => r.attendance_status === 'present').length,
        late: attendanceRecords.filter(r => r.attendance_status === 'late').length,
        absent: attendanceRecords.filter(r => r.attendance_status === 'absent').length
      },
      averageSessionDuration: attendanceRecords
        .filter(r => r.session_duration_minutes)
        .reduce((sum, r) => sum + r.session_duration_minutes, 0) / 
        attendanceRecords.filter(r => r.session_duration_minutes).length || 0
    },
    insights: generateInsights(attendanceRecords),
    generatedAt: moment().toISOString()
  };

  return analytics;
}

function generateDailyTrend(attendanceRecords) {
  const dailyData = _.groupBy(attendanceRecords, 'date');
  const trend = {};

  for (const [date, records] of Object.entries(dailyData)) {
    trend[date] = {
      total: records.length,
      present: records.filter(r => r.attendance_status === 'present').length,
      late: records.filter(r => r.attendance_status === 'late').length,
      rate: records.length > 0 ? (records.filter(r => r.attendance_status === 'present').length / records.length * 100).toFixed(2) : 0
    };
  }

  return trend;
}

function generateInsights(attendanceRecords) {
  const insights = [];

  // Peak attendance day
  const dailyData = _.groupBy(attendanceRecords, 'date');
  const peakDay = Object.entries(dailyData).reduce((max, [date, records]) => 
    records.length > max.count ? { date, count: records.length } : max, 
    { date: null, count: 0 }
  );

  if (peakDay.date) {
    insights.push({
      type: 'peak_day',
      message: `Highest attendance was on ${peakDay.date} with ${peakDay.count} attendees`,
      value: peakDay.count,
      date: peakDay.date
    });
  }

  // Late arrival trend
  const lateCount = attendanceRecords.filter(r => r.attendance_status === 'late').length;
  const latePercentage = attendanceRecords.length > 0 ? (lateCount / attendanceRecords.length * 100).toFixed(2) : 0;

  insights.push({
    type: 'late_trend',
    message: `${latePercentage}% of attendances were marked as late`,
    value: parseFloat(latePercentage),
    count: lateCount
  });

  // QR code usage
  const qrUsage = attendanceRecords.filter(r => r.qr_code_used).length;
  const qrPercentage = attendanceRecords.length > 0 ? (qrUsage / attendanceRecords.length * 100).toFixed(2) : 0;

  insights.push({
    type: 'qr_usage',
    message: `${qrPercentage}% of check-ins used QR codes`,
    value: parseFloat(qrPercentage),
    count: qrUsage
  });

  return insights;
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

async function convertToCSV(report, reportType) {
  let data = [];
  let fields = [];

  switch (reportType) {
    case 'detailed':
      data = report.attendanceRecords;
      fields = [
        'attendanceId', 'userId', 'userName', 'classId', 'className', 
        'courseCode', 'date', 'checkInTime', 'checkOutTime', 'status', 
        'sessionDuration', 'qrCodeUsed'
      ];
      break;
    case 'summary':
      data = Object.entries(report.dailyBreakdown).map(([date, stats]) => ({
        date,
        ...stats
      }));
      fields = ['date', 'totalAttendees', 'presentCount', 'lateCount', 'attendanceRate'];
      break;
    case 'class':
      data = Object.entries(report.studentSummary).map(([userId, stats]) => ({
        userId,
        ...stats
      }));
      fields = ['userId', 'userName', 'totalSessions', 'presentCount', 'lateCount', 'attendanceRate', 'averageSessionDuration'];
      break;
    case 'student':
      data = Object.entries(report.studentReports).map(([userId, stats]) => ({
        userId,
        ...stats
      }));
      fields = ['userId', 'userName', 'totalSessions', 'presentCount', 'lateCount', 'attendanceRate', 'averageSessionDuration'];
      break;
  }

  const parser = new Parser({ fields });
  return parser.parse(data);
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