#!/bin/bash

# =============================================================================
# User Data Script for Marks Management EC2 Instances
# =============================================================================

# Set variables from template
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"
APP_PORT="${app_port}"
NODE_ENV="${node_env}"
DB_SECRET_ARN="${db_secret_arn}"
REGION="${region}"
LOG_GROUP_NAME="${log_group_name}"

# Log all output
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user data script execution..."
echo "Project: $PROJECT_NAME"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"

# Update system
echo "Updating system packages..."
yum update -y

# Install required packages
echo "Installing required packages..."
yum install -y \
    git \
    curl \
    wget \
    unzip \
    htop \
    nginx \
    amazon-cloudwatch-agent \
    awscli

# Install Node.js 18.x
echo "Installing Node.js..."
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Verify Node.js installation
node --version
npm --version

# Install PM2 for process management
echo "Installing PM2..."
npm install -g pm2

# Create application user
echo "Creating application user..."
useradd -m -s /bin/bash appuser
usermod -aG wheel appuser

# Create application directories
echo "Creating application directories..."
mkdir -p /opt/marks-api
mkdir -p /var/log/marks-api
mkdir -p /etc/marks-api

# Set ownership
chown -R appuser:appuser /opt/marks-api
chown -R appuser:appuser /var/log/marks-api
chown -R appuser:appuser /etc/marks-api

# Download and setup application code
echo "Setting up application code..."
cd /opt/marks-api

# Create a basic Express.js application structure
cat > package.json << 'EOF'
{
  "name": "marks-management-api",
  "version": "1.0.0",
  "description": "Marks Management API for Education Platform",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "morgan": "^1.10.0",
    "dotenv": "^16.3.1",
    "joi": "^17.11.0",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2",
    "aws-sdk": "^2.1490.0",
    "compression": "^1.7.4",
    "express-rate-limit": "^7.1.5",
    "express-validator": "^7.0.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1",
    "jest": "^29.7.0",
    "supertest": "^6.3.3"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

# Install dependencies
echo "Installing Node.js dependencies..."
sudo -u appuser npm install

# Create main application file
cat > app.js << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const AWS = require('aws-sdk');
const { Pool } = require('pg');

const app = express();
const port = process.env.APP_PORT || 3000;

// AWS Configuration
AWS.config.update({ region: process.env.AWS_REGION || 'us-east-1' });
const secretsManager = new AWS.SecretsManager();

// Database connection pool
let dbPool;

// Initialize database connection
async function initializeDatabase() {
  try {
    console.log('Retrieving database credentials from Secrets Manager...');
    const secret = await secretsManager.getSecretValue({
      SecretId: process.env.DB_SECRET_ARN
    }).promise();
    
    const credentials = JSON.parse(secret.SecretString);
    
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

// Run database migrations
async function runMigrations() {
  try {
    console.log('Running database migrations...');
    
    // Create tables if they don't exist
    await dbPool.query(`
      CREATE TABLE IF NOT EXISTS students (
        id SERIAL PRIMARY KEY,
        user_id VARCHAR(255) UNIQUE NOT NULL,
        student_number VARCHAR(50) UNIQUE NOT NULL,
        first_name VARCHAR(100) NOT NULL,
        last_name VARCHAR(100) NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        department VARCHAR(100),
        year_level INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    await dbPool.query(`
      CREATE TABLE IF NOT EXISTS courses (
        id SERIAL PRIMARY KEY,
        course_code VARCHAR(20) UNIQUE NOT NULL,
        course_name VARCHAR(200) NOT NULL,
        description TEXT,
        credits INTEGER DEFAULT 3,
        instructor_id VARCHAR(255),
        department VARCHAR(100),
        semester VARCHAR(20),
        year INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    await dbPool.query(`
      CREATE TABLE IF NOT EXISTS assignments (
        id SERIAL PRIMARY KEY,
        course_id INTEGER REFERENCES courses(id) ON DELETE CASCADE,
        title VARCHAR(200) NOT NULL,
        description TEXT,
        max_score DECIMAL(5,2) NOT NULL,
        due_date TIMESTAMP,
        assignment_type VARCHAR(50) DEFAULT 'assignment',
        weight DECIMAL(3,2) DEFAULT 1.0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    await dbPool.query(`
      CREATE TABLE IF NOT EXISTS grades (
        id SERIAL PRIMARY KEY,
        student_id INTEGER REFERENCES students(id) ON DELETE CASCADE,
        assignment_id INTEGER REFERENCES assignments(id) ON DELETE CASCADE,
        score DECIMAL(5,2),
        feedback TEXT,
        graded_by VARCHAR(255),
        graded_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(student_id, assignment_id)
      );
    `);

    await dbPool.query(`
      CREATE TABLE IF NOT EXISTS enrollments (
        id SERIAL PRIMARY KEY,
        student_id INTEGER REFERENCES students(id) ON DELETE CASCADE,
        course_id INTEGER REFERENCES courses(id) ON DELETE CASCADE,
        enrollment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        status VARCHAR(20) DEFAULT 'active',
        UNIQUE(student_id, course_id)
      );
    `);

    // Create indexes for better performance
    await dbPool.query(`
      CREATE INDEX IF NOT EXISTS idx_students_user_id ON students(user_id);
      CREATE INDEX IF NOT EXISTS idx_grades_student_id ON grades(student_id);
      CREATE INDEX IF NOT EXISTS idx_grades_assignment_id ON grades(assignment_id);
      CREATE INDEX IF NOT EXISTS idx_enrollments_student_id ON enrollments(student_id);
      CREATE INDEX IF NOT EXISTS idx_enrollments_course_id ON enrollments(course_id);
    `);

    console.log('Database migrations completed successfully');
  } catch (error) {
    console.error('Migration failed:', error);
    throw error;
  }
}

// Middleware
app.use(helmet());
app.use(compression());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use('/api/', limiter);

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    // Check database connection
    const client = await dbPool.connect();
    await client.query('SELECT 1');
    client.release();
    
    res.status(200).json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: process.env.NODE_ENV,
      version: '1.0.0'
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// API Routes
app.get('/api/v1/students', async (req, res) => {
  try {
    const result = await dbPool.query('SELECT * FROM students ORDER BY last_name, first_name');
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching students:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/api/v1/courses', async (req, res) => {
  try {
    const result = await dbPool.query('SELECT * FROM courses ORDER BY course_code');
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching courses:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/api/v1/grades/:studentId', async (req, res) => {
  try {
    const { studentId } = req.params;
    const result = await dbPool.query(`
      SELECT g.*, a.title as assignment_title, a.max_score, c.course_name, c.course_code
      FROM grades g
      JOIN assignments a ON g.assignment_id = a.id
      JOIN courses c ON a.course_id = c.id
      JOIN students s ON g.student_id = s.id
      WHERE s.user_id = $1
      ORDER BY g.created_at DESC
    `, [studentId]);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching grades:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Start server
async function startServer() {
  try {
    await initializeDatabase();
    
    app.listen(port, '0.0.0.0', () => {
      console.log(`Marks Management API server running on port ${port}`);
      console.log(`Environment: ${process.env.NODE_ENV}`);
      console.log(`Health check: http://localhost:${port}/health`);
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

startServer();
EOF

# Create environment configuration
cat > .env << EOF
NODE_ENV=$NODE_ENV
APP_PORT=$APP_PORT
AWS_REGION=$REGION
DB_SECRET_ARN=$DB_SECRET_ARN
LOG_GROUP_NAME=$LOG_GROUP_NAME
EOF

# Set ownership
chown -R appuser:appuser /opt/marks-api

# Configure PM2 ecosystem
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'marks-api',
    script: 'app.js',
    instances: 'max',
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production'
    },
    log_file: '/var/log/marks-api/combined.log',
    out_file: '/var/log/marks-api/out.log',
    error_file: '/var/log/marks-api/error.log',
    time: true,
    max_memory_restart: '1G',
    node_args: '--max-old-space-size=1024'
  }]
};
EOF

# Configure Nginx as reverse proxy
cat > /etc/nginx/conf.d/marks-api.conf << EOF
upstream marks_api {
    server 127.0.0.1:$APP_PORT;
}

server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    location /health {
        proxy_pass http://marks_api;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 5s;
        proxy_send_timeout 10s;
        proxy_read_timeout 10s;
    }

    location / {
        proxy_pass http://marks_api;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}
EOF

# Remove default Nginx configuration
rm -f /etc/nginx/conf.d/default.conf

# Configure CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/marks-api/combined.log",
            "log_group_name": "$LOG_GROUP_NAME",
            "log_stream_name": "{instance_id}/application",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/marks-api/error.log",
            "log_group_name": "$LOG_GROUP_NAME",
            "log_stream_name": "{instance_id}/error",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "$LOG_GROUP_NAME",
            "log_stream_name": "{instance_id}/nginx-access",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "$LOG_GROUP_NAME",
            "log_stream_name": "{instance_id}/nginx-error",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "diskio": {
        "measurement": [
          "io_time"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "netstat": {
        "measurement": [
          "tcp_established",
          "tcp_time_wait"
        ],
        "metrics_collection_interval": 60
      },
      "swap": {
        "measurement": [
          "swap_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# Start and enable services
echo "Starting services..."
systemctl enable nginx
systemctl start nginx

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Start the application with PM2
echo "Starting application..."
cd /opt/marks-api
sudo -u appuser pm2 start ecosystem.config.js
sudo -u appuser pm2 save
sudo -u appuser pm2 startup

# Create systemd service for PM2
env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u appuser --hp /home/appuser

# Wait for application to start
sleep 30

# Test the application
echo "Testing application..."
curl -f http://localhost:$APP_PORT/health || {
    echo "Application health check failed"
    exit 1
}

echo "User data script completed successfully!"
echo "Application is running on port $APP_PORT"
echo "Nginx is proxying requests on port 80"
echo "Logs are being sent to CloudWatch: $LOG_GROUP_NAME"