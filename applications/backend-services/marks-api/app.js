/**
 * Marks Management API
 * 
 * Express.js application for managing student grades and marks
 * Features:
 * - Student grade management
 * - Course and assignment management
 * - Grade calculations and analytics
 * - Integration with AWS services
 */

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const { body, param, query, validationResult } = require('express-validator');
const AWS = require('aws-sdk');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// Initialize Express app
const app = express();
const port = process.env.APP_PORT || 3000;

// AWS Configuration
AWS.config.update({ region: process.env.AWS_REGION || 'us-east-1' });
const secretsManager = new AWS.SecretsManager();
const cloudWatch = new AWS.CloudWatch();

// Database connection pool
let dbPool;

// =============================================================================
// Database Initialization
// =============================================================================

async function initializeDatabase() {
  try {
    let credentials;
    
    if (process.env.DB_SECRET_ARN) {
      console.log('Retrieving database credentials from Secrets Manager...');
      const secret = await secretsManager.getSecretValue({
        SecretId: process.env.DB_SECRET_ARN
      }).promise();
      
      credentials = JSON.parse(secret.SecretString);
    } else {
      // Fallback to environment variables for development
      credentials = {
        host: process.env.DB_HOST || 'localhost',
        port: process.env.DB_PORT || 5432,
        dbname: process.env.DB_NAME || 'education_platform_dev',
        username: process.env.DB_USERNAME || 'eduadmin',
        password: process.env.DB_PASSWORD || 'password'
      };
    }
    
    dbPool = new Pool({
      host: credentials.host,
      port: credentials.port,
      database: credentials.dbname,
      user: credentials.username,
      password: credentials.password,
      ssl: {
        rejectUnauthorized: false
      },
      max: 20,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 2000,
    });

    // Test connection
    const client = await dbPool.connect();
    console.log('Database connected successfully');
    client.release();
    
    // Run migrations
    await runMigrations();
    
  } catch (error) {
    console.error('Database initialization failed:', error);
    process.exit(1);
  }
}

async function runMigrations() {
  try {
    console.log('Running database migrations...');
    
    // Check if migrations table exists
    const migrationTableExists = await dbPool.query(`
      SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'migrations'
      );
    `);
    
    if (!migrationTableExists.rows[0].exists) {
      // Create migrations table
      await dbPool.query(`
        CREATE TABLE migrations (
          id SERIAL PRIMARY KEY,
          filename VARCHAR(255) NOT NULL,
          executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
      `);
    }
    
    // Check if initial migration has been run
    const initialMigration = await dbPool.query(`
      SELECT * FROM migrations WHERE filename = '001_initial.sql';
    `);
    
    if (initialMigration.rows.length === 0) {
      // Run initial migration (this would normally read from file)
      console.log('Running initial migration...');
      // The migration SQL is embedded in the user data script
      // In a real application, you would read and execute the SQL file
      
      await dbPool.query(`
        INSERT INTO migrations (filename) VALUES ('001_initial.sql');
      `);
      
      console.log('Initial migration completed');
    }
    
    console.log('Database migrations completed successfully');
  } catch (error) {
    console.error('Migration failed:', error);
    throw error;
  }
}

// =============================================================================
// Middleware Configuration
// =============================================================================

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

app.use(compression());
app.use(cors({
  origin: process.env.CORS_ORIGINS ? process.env.CORS_ORIGINS.split(',') : '*',
  credentials: true
}));

// Logging
app.use(morgan('combined', {
  stream: {
    write: (message) => {
      console.log(message.trim());
      // Send logs to CloudWatch in production
      if (process.env.NODE_ENV === 'production') {
        sendLogToCloudWatch('application', message.trim());
      }
    }
  }
}));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: {
    error: 'Too many requests from this IP, please try again later.'
  }
});
app.use('/api/', limiter);

// =============================================================================
// Authentication Middleware
// =============================================================================

function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  try {
    // In a real application, you would verify the JWT token
    // For now, we'll decode it to get user information
    const decoded = jwt.decode(token);
    if (!decoded) {
      return res.status(403).json({ error: 'Invalid token' });
    }
    
    req.user = {
      id: decoded.sub,
      email: decoded.email,
      groups: decoded['cognito:groups'] || []
    };
    
    next();
  } catch (error) {
    return res.status(403).json({ error: 'Invalid token' });
  }
}

function requireRole(roles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    const userRoles = req.user.groups || [];
    const hasRole = roles.some(role => userRoles.includes(role));
    
    if (!hasRole) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    
    next();
  };
}

// =============================================================================
// Validation Middleware
// =============================================================================

function handleValidationErrors(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      details: errors.array()
    });
  }
  next();
}

// =============================================================================
// Health Check Endpoint
// =============================================================================

app.get('/health', async (req, res) => {
  try {
    // Check database connection
    const client = await dbPool.connect();
    await client.query('SELECT 1');
    client.release();
    
    // Send custom metric to CloudWatch
    await sendMetricToCloudWatch('HealthCheck', 1, 'Count');
    
    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: process.env.NODE_ENV,
      version: '1.0.0',
      database: 'connected'
    });
  } catch (error) {
    console.error('Health check failed:', error);
    res.status(503).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// =============================================================================
// API Routes - Students
// =============================================================================

// Get all students
app.get('/api/v1/students', 
  authenticateToken,
  requireRole(['teachers', 'admins']),
  [
    query('page').optional().isInt({ min: 1 }),
    query('limit').optional().isInt({ min: 1, max: 100 }),
    query('department').optional().isString(),
    query('status').optional().isIn(['active', 'inactive', 'graduated', 'suspended'])
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 20;
      const offset = (page - 1) * limit;
      
      let query = 'SELECT * FROM students';
      let countQuery = 'SELECT COUNT(*) FROM students';
      const params = [];
      const conditions = [];
      
      if (req.query.department) {
        conditions.push(`department = $${params.length + 1}`);
        params.push(req.query.department);
      }
      
      if (req.query.status) {
        conditions.push(`status = $${params.length + 1}`);
        params.push(req.query.status);
      }
      
      if (conditions.length > 0) {
        const whereClause = ' WHERE ' + conditions.join(' AND ');
        query += whereClause;
        countQuery += whereClause;
      }
      
      query += ` ORDER BY last_name, first_name LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
      params.push(limit, offset);
      
      const [studentsResult, countResult] = await Promise.all([
        dbPool.query(query, params),
        dbPool.query(countQuery, params.slice(0, -2))
      ]);
      
      const totalCount = parseInt(countResult.rows[0].count);
      const totalPages = Math.ceil(totalCount / limit);
      
      res.json({
        students: studentsResult.rows,
        pagination: {
          page,
          limit,
          totalCount,
          totalPages,
          hasNext: page < totalPages,
          hasPrev: page > 1
        }
      });
    } catch (error) {
      console.error('Error fetching students:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// Get student by ID
app.get('/api/v1/students/:id',
  authenticateToken,
  [param('id').isInt()],
  handleValidationErrors,
  async (req, res) => {
    try {
      const studentId = req.params.id;
      
      // Check if user can access this student's data
      const isTeacherOrAdmin = req.user.groups.some(group => ['teachers', 'admins'].includes(group));
      
      let query = `
        SELECT s.*, 
               COUNT(DISTINCT e.course_id) as enrolled_courses,
               AVG(g.percentage) as overall_average
        FROM students s
        LEFT JOIN enrollments e ON s.id = e.student_id AND e.status = 'active'
        LEFT JOIN grades g ON s.id = g.student_id AND g.status = 'graded'
        WHERE s.id = $1
      `;
      
      // Students can only access their own data
      if (!isTeacherOrAdmin) {
        query += ` AND s.user_id = $2`;
      }
      
      query += ` GROUP BY s.id`;
      
      const params = isTeacherOrAdmin ? [studentId] : [studentId, req.user.id];
      const result = await dbPool.query(query, params);
      
      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Student not found' });
      }
      
      res.json(result.rows[0]);
    } catch (error) {
      console.error('Error fetching student:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// =============================================================================
// API Routes - Courses
// =============================================================================

// Get all courses
app.get('/api/v1/courses',
  authenticateToken,
  [
    query('page').optional().isInt({ min: 1 }),
    query('limit').optional().isInt({ min: 1, max: 100 }),
    query('department').optional().isString(),
    query('semester').optional().isIn(['fall', 'spring', 'summer']),
    query('year').optional().isInt({ min: 2020 })
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 20;
      const offset = (page - 1) * limit;
      
      let query = `
        SELECT c.*, 
               COUNT(DISTINCT e.student_id) as enrolled_students,
               COUNT(DISTINCT a.id) as total_assignments
        FROM courses c
        LEFT JOIN enrollments e ON c.id = e.course_id AND e.status = 'active'
        LEFT JOIN assignments a ON c.id = a.course_id AND a.is_published = true
      `;
      
      let countQuery = 'SELECT COUNT(*) FROM courses c';
      const params = [];
      const conditions = [];
      
      // Add filters
      if (req.query.department) {
        conditions.push(`c.department = $${params.length + 1}`);
        params.push(req.query.department);
      }
      
      if (req.query.semester) {
        conditions.push(`c.semester = $${params.length + 1}`);
        params.push(req.query.semester);
      }
      
      if (req.query.year) {
        conditions.push(`c.year = $${params.length + 1}`);
        params.push(req.query.year);
      }
      
      // Filter by instructor for teachers
      if (req.user.groups.includes('teachers') && !req.user.groups.includes('admins')) {
        conditions.push(`c.instructor_id = $${params.length + 1}`);
        params.push(req.user.id);
      }
      
      if (conditions.length > 0) {
        const whereClause = ' WHERE ' + conditions.join(' AND ');
        query += whereClause;
        countQuery += whereClause;
      }
      
      query += ` GROUP BY c.id ORDER BY c.course_code LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
      params.push(limit, offset);
      
      const [coursesResult, countResult] = await Promise.all([
        dbPool.query(query, params),
        dbPool.query(countQuery, params.slice(0, -2))
      ]);
      
      const totalCount = parseInt(countResult.rows[0].count);
      const totalPages = Math.ceil(totalCount / limit);
      
      res.json({
        courses: coursesResult.rows,
        pagination: {
          page,
          limit,
          totalCount,
          totalPages,
          hasNext: page < totalPages,
          hasPrev: page > 1
        }
      });
    } catch (error) {
      console.error('Error fetching courses:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// =============================================================================
// API Routes - Assignments
// =============================================================================

// Get assignments for a course
app.get('/api/v1/courses/:courseId/assignments',
  authenticateToken,
  [param('courseId').isInt()],
  handleValidationErrors,
  async (req, res) => {
    try {
      const courseId = req.params.courseId;
      
      // Check if user has access to this course
      const accessQuery = `
        SELECT c.* FROM courses c
        LEFT JOIN enrollments e ON c.id = e.course_id AND e.student_id = (
          SELECT id FROM students WHERE user_id = $2
        )
        WHERE c.id = $1 AND (
          c.instructor_id = $2 OR 
          e.id IS NOT NULL OR 
          $3 = ANY($4::text[])
        )
      `;
      
      const accessResult = await dbPool.query(accessQuery, [
        courseId, 
        req.user.id, 
        'admins', 
        req.user.groups
      ]);
      
      if (accessResult.rows.length === 0) {
        return res.status(403).json({ error: 'Access denied to this course' });
      }
      
      const query = `
        SELECT a.*,
               COUNT(g.id) as submissions,
               AVG(g.percentage) as average_score
        FROM assignments a
        LEFT JOIN grades g ON a.id = g.assignment_id AND g.status = 'graded'
        WHERE a.course_id = $1 AND a.is_published = true
        GROUP BY a.id
        ORDER BY a.due_date ASC, a.created_at ASC
      `;
      
      const result = await dbPool.query(query, [courseId]);
      res.json(result.rows);
    } catch (error) {
      console.error('Error fetching assignments:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// =============================================================================
// API Routes - Grades
// =============================================================================

// Get grades for a student
app.get('/api/v1/students/:studentId/grades',
  authenticateToken,
  [
    param('studentId').isInt(),
    query('courseId').optional().isInt()
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const studentId = req.params.studentId;
      const courseId = req.query.courseId;
      
      // Check access permissions
      const isTeacherOrAdmin = req.user.groups.some(group => ['teachers', 'admins'].includes(group));
      const studentQuery = await dbPool.query('SELECT user_id FROM students WHERE id = $1', [studentId]);
      
      if (studentQuery.rows.length === 0) {
        return res.status(404).json({ error: 'Student not found' });
      }
      
      const isOwnData = studentQuery.rows[0].user_id === req.user.id;
      
      if (!isTeacherOrAdmin && !isOwnData) {
        return res.status(403).json({ error: 'Access denied' });
      }
      
      let query = `
        SELECT g.*, 
               a.title as assignment_title, 
               a.max_score, 
               a.assignment_type,
               a.due_date,
               c.course_name, 
               c.course_code
        FROM grades g
        JOIN assignments a ON g.assignment_id = a.id
        JOIN courses c ON a.course_id = c.id
        WHERE g.student_id = $1
      `;
      
      const params = [studentId];
      
      if (courseId) {
        query += ` AND c.id = $${params.length + 1}`;
        params.push(courseId);
      }
      
      query += ` ORDER BY g.created_at DESC`;
      
      const result = await dbPool.query(query, params);
      res.json(result.rows);
    } catch (error) {
      console.error('Error fetching grades:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// Create or update a grade
app.post('/api/v1/grades',
  authenticateToken,
  requireRole(['teachers', 'admins']),
  [
    body('studentId').isInt(),
    body('assignmentId').isInt(),
    body('score').isFloat({ min: 0 }),
    body('feedback').optional().isString()
  ],
  handleValidationErrors,
  async (req, res) => {
    try {
      const { studentId, assignmentId, score, feedback } = req.body;
      
      // Verify teacher has access to this assignment
      const assignmentQuery = `
        SELECT a.*, c.instructor_id 
        FROM assignments a 
        JOIN courses c ON a.course_id = c.id 
        WHERE a.id = $1
      `;
      
      const assignmentResult = await dbPool.query(assignmentQuery, [assignmentId]);
      
      if (assignmentResult.rows.length === 0) {
        return res.status(404).json({ error: 'Assignment not found' });
      }
      
      const assignment = assignmentResult.rows[0];
      
      // Check if user is instructor or admin
      if (assignment.instructor_id !== req.user.id && !req.user.groups.includes('admins')) {
        return res.status(403).json({ error: 'Access denied' });
      }
      
      // Validate score doesn't exceed max_score
      if (score > assignment.max_score) {
        return res.status(400).json({ 
          error: `Score cannot exceed maximum score of ${assignment.max_score}` 
        });
      }
      
      // Insert or update grade
      const gradeQuery = `
        INSERT INTO grades (student_id, assignment_id, score, feedback, graded_by, graded_at, status)
        VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP, 'graded')
        ON CONFLICT (student_id, assignment_id)
        DO UPDATE SET 
          score = EXCLUDED.score,
          feedback = EXCLUDED.feedback,
          graded_by = EXCLUDED.graded_by,
          graded_at = EXCLUDED.graded_at,
          status = EXCLUDED.status,
          updated_at = CURRENT_TIMESTAMP
        RETURNING *
      `;
      
      const gradeResult = await dbPool.query(gradeQuery, [
        studentId, assignmentId, score, feedback, req.user.id
      ]);
      
      // Send metric to CloudWatch
      await sendMetricToCloudWatch('GradeCreated', 1, 'Count');
      
      res.status(201).json(gradeResult.rows[0]);
    } catch (error) {
      console.error('Error creating/updating grade:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// =============================================================================
// API Routes - Reports
// =============================================================================

// Get grade report for a course
app.get('/api/v1/courses/:courseId/reports',
  authenticateToken,
  requireRole(['teachers', 'admins']),
  [param('courseId').isInt()],
  handleValidationErrors,
  async (req, res) => {
    try {
      const courseId = req.params.courseId;
      
      // Verify access to course
      const courseQuery = `
        SELECT * FROM courses 
        WHERE id = $1 AND (instructor_id = $2 OR $3 = ANY($4::text[]))
      `;
      
      const courseResult = await dbPool.query(courseQuery, [
        courseId, req.user.id, 'admins', req.user.groups
      ]);
      
      if (courseResult.rows.length === 0) {
        return res.status(403).json({ error: 'Access denied to this course' });
      }
      
      // Get comprehensive course report
      const reportQuery = `
        SELECT 
          s.id as student_id,
          s.student_number,
          s.first_name,
          s.last_name,
          COUNT(g.id) as total_grades,
          AVG(g.percentage) as average_percentage,
          STRING_AGG(DISTINCT g.letter_grade, ', ' ORDER BY g.letter_grade) as letter_grades,
          MAX(g.graded_at) as last_graded
        FROM students s
        JOIN enrollments e ON s.id = e.student_id
        LEFT JOIN assignments a ON e.course_id = a.course_id AND a.is_published = true
        LEFT JOIN grades g ON s.id = g.student_id AND a.id = g.assignment_id AND g.status = 'graded'
        WHERE e.course_id = $1 AND e.status = 'active'
        GROUP BY s.id, s.student_number, s.first_name, s.last_name
        ORDER BY s.last_name, s.first_name
      `;
      
      const reportResult = await dbPool.query(reportQuery, [courseId]);
      
      // Get course statistics
      const statsQuery = `
        SELECT 
          COUNT(DISTINCT s.id) as total_students,
          COUNT(DISTINCT a.id) as total_assignments,
          AVG(g.percentage) as class_average,
          COUNT(CASE WHEN g.letter_grade IN ('A+', 'A', 'A-') THEN 1 END) as a_grades,
          COUNT(CASE WHEN g.letter_grade IN ('B+', 'B', 'B-') THEN 1 END) as b_grades,
          COUNT(CASE WHEN g.letter_grade IN ('C+', 'C', 'C-') THEN 1 END) as c_grades,
          COUNT(CASE WHEN g.letter_grade IN ('D+', 'D', 'D-') THEN 1 END) as d_grades,
          COUNT(CASE WHEN g.letter_grade = 'F' THEN 1 END) as f_grades
        FROM enrollments e
        JOIN students s ON e.student_id = s.id
        LEFT JOIN assignments a ON e.course_id = a.course_id AND a.is_published = true
        LEFT JOIN grades g ON s.id = g.student_id AND a.id = g.assignment_id AND g.status = 'graded'
        WHERE e.course_id = $1 AND e.status = 'active'
      `;
      
      const statsResult = await dbPool.query(statsQuery, [courseId]);
      
      res.json({
        course: courseResult.rows[0],
        students: reportResult.rows,
        statistics: statsResult.rows[0]
      });
    } catch (error) {
      console.error('Error generating course report:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// =============================================================================
// Utility Functions
// =============================================================================

async function sendMetricToCloudWatch(metricName, value, unit) {
  if (process.env.NODE_ENV !== 'production') return;
  
  try {
    const params = {
      Namespace: 'EducationPlatform/MarksAPI',
      MetricData: [
        {
          MetricName: metricName,
          Value: value,
          Unit: unit,
          Timestamp: new Date()
        }
      ]
    };
    
    await cloudWatch.putMetricData(params).promise();
  } catch (error) {
    console.error('Error sending metric to CloudWatch:', error);
  }
}

async function sendLogToCloudWatch(logGroup, message) {
  // This would integrate with CloudWatch Logs
  // For now, just console.log
  console.log(`[${logGroup}] ${message}`);
}

// =============================================================================
// Error Handling
// =============================================================================

// 404 handler
app.use((req, res) => {
  res.status(404).json({ 
    error: 'Not found',
    path: req.path,
    method: req.method
  });
});

// Global error handler
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  
  // Send error metric to CloudWatch
  sendMetricToCloudWatch('UnhandledError', 1, 'Count');
  
  res.status(500).json({ 
    error: 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { details: error.message })
  });
});

// =============================================================================
// Server Startup
// =============================================================================

async function startServer() {
  try {
    await initializeDatabase();
    
    app.listen(port, '0.0.0.0', () => {
      console.log(`Marks Management API server running on port ${port}`);
      console.log(`Environment: ${process.env.NODE_ENV}`);
      console.log(`Health check: http://localhost:${port}/health`);
      console.log(`API base URL: http://localhost:${port}/api/v1`);
      
      // Send startup metric
      sendMetricToCloudWatch('ServerStartup', 1, 'Count');
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  if (dbPool) {
    await dbPool.end();
  }
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully');
  if (dbPool) {
    await dbPool.end();
  }
  process.exit(0);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  sendMetricToCloudWatch('UncaughtException', 1, 'Count');
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  sendMetricToCloudWatch('UnhandledRejection', 1, 'Count');
});

// Start the server
startServer();