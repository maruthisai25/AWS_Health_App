# =============================================================================
# Lambda Functions for Attendance System
# =============================================================================

# Security Group for Lambda Functions
resource "aws_security_group" "attendance_lambda" {
  name_prefix = "${var.project_name}-${var.environment}-attendance-lambda-"
  vpc_id      = var.vpc_id

  # Outbound rules
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for AWS API calls"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound for external APIs"
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-attendance-lambda-sg"
    Component = "attendance"
    Purpose   = "lambda-security"
  })
}

# IAM Role for Lambda Functions
resource "aws_iam_role" "attendance_lambda" {
  name = "${var.project_name}-${var.environment}-attendance-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-attendance-lambda-role"
    Component = "attendance"
    Purpose   = "lambda-execution"
  })
}

# IAM Policy for Lambda Functions
resource "aws_iam_role_policy" "attendance_lambda" {
  name = "${var.project_name}-${var.environment}-attendance-lambda-policy"
  role = aws_iam_role.attendance_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.attendance.arn,
          "${aws_dynamodb_table.attendance.arn}/index/*",
          aws_dynamodb_table.classes.arn,
          "${aws_dynamodb_table.classes.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.notification_topic_arn != "" ? [var.notification_topic_arn] : []
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = var.report_s3_bucket != "" ? ["${var.report_s3_bucket}/*"] : []
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arn != "" ? [var.kms_key_arn] : []
      }
    ]
  })
}

# Attach VPC execution policy
resource "aws_iam_role_policy_attachment" "attendance_lambda_vpc" {
  role       = aws_iam_role.attendance_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Attach X-Ray tracing policy (if enabled)
resource "aws_iam_role_policy_attachment" "attendance_lambda_xray" {
  count      = var.enable_xray_tracing ? 1 : 0
  role       = aws_iam_role.attendance_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# =============================================================================
# Lambda Function Source Code Archives
# =============================================================================

# Attendance Tracker Lambda Archive
data "archive_file" "attendance_tracker" {
  type        = "zip"
  source_dir  = "${path.module}/../../../applications/lambda-functions/attendance-tracker"
  output_path = "${path.module}/attendance-tracker.zip"
}

# Attendance Reporter Lambda Archive
data "archive_file" "attendance_reporter" {
  type        = "zip"
  source_dir  = "${path.module}/../../../applications/lambda-functions/attendance-reporter"
  output_path = "${path.module}/attendance-reporter.zip"
}

# =============================================================================
# CloudWatch Log Groups
# =============================================================================

resource "aws_cloudwatch_log_group" "attendance_tracker" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-attendance-tracker"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-attendance-tracker-logs"
    Component = "attendance"
    Purpose   = "lambda-logs"
  })
}

resource "aws_cloudwatch_log_group" "attendance_reporter" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-attendance-reporter"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-attendance-reporter-logs"
    Component = "attendance"
    Purpose   = "lambda-logs"
  })
}

# =============================================================================
# Lambda Functions
# =============================================================================

# Attendance Tracker Lambda Function
resource "aws_lambda_function" "attendance_tracker" {
  filename         = data.archive_file.attendance_tracker.output_path
  function_name    = "${var.project_name}-${var.environment}-attendance-tracker"
  role            = aws_iam_role.attendance_lambda.arn
  handler         = "index.handler"
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  source_code_hash = data.archive_file.attendance_tracker.output_base64sha256

  # VPC Configuration
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.attendance_lambda.id]
  }

  # Environment Variables
  environment {
    variables = {
      ATTENDANCE_TABLE_NAME           = aws_dynamodb_table.attendance.name
      CLASSES_TABLE_NAME             = aws_dynamodb_table.classes.name
      USER_POOL_ID                   = var.user_pool_id
      ENVIRONMENT                    = var.environment
      SESSION_DURATION_MINUTES       = var.attendance_session_duration
      GEOLOCATION_RADIUS_METERS      = var.geolocation_radius_meters
      ENABLE_GEOLOCATION_VALIDATION  = var.enable_geolocation_validation
      QR_CODE_EXPIRY_MINUTES         = var.qr_code_expiry_minutes
      GRACE_PERIOD_MINUTES           = var.attendance_grace_period_minutes
      NOTIFICATION_TOPIC_ARN         = var.notification_topic_arn
      ENABLE_NOTIFICATIONS           = var.enable_attendance_notifications
    }
  }

  # Reserved Concurrency
  reserved_concurrent_executions = var.lambda_reserved_concurrency

  # X-Ray Tracing
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  # Dead Letter Queue
  dead_letter_config {
    target_arn = aws_sqs_queue.attendance_dlq.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.attendance_lambda_vpc,
    aws_cloudwatch_log_group.attendance_tracker
  ]

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-attendance-tracker"
    Component = "attendance"
    Purpose   = "attendance-tracking"
  })
}

# Attendance Reporter Lambda Function
resource "aws_lambda_function" "attendance_reporter" {
  filename         = data.archive_file.attendance_reporter.output_path
  function_name    = "${var.project_name}-${var.environment}-attendance-reporter"
  role            = aws_iam_role.attendance_lambda.arn
  handler         = "index.handler"
  runtime         = var.lambda_runtime
  timeout         = 300  # Longer timeout for report generation
  memory_size     = 512  # More memory for report processing
  source_code_hash = data.archive_file.attendance_reporter.output_base64sha256

  # VPC Configuration
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.attendance_lambda.id]
  }

  # Environment Variables
  environment {
    variables = {
      ATTENDANCE_TABLE_NAME    = aws_dynamodb_table.attendance.name
      CLASSES_TABLE_NAME      = aws_dynamodb_table.classes.name
      USER_POOL_ID            = var.user_pool_id
      ENVIRONMENT             = var.environment
      ENABLE_CSV_EXPORT       = var.enable_csv_export
      REPORT_S3_BUCKET        = var.report_s3_bucket
      ENABLE_ANALYTICS        = var.enable_attendance_analytics
      NOTIFICATION_TOPIC_ARN  = var.notification_topic_arn
    }
  }

  # X-Ray Tracing
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  # Dead Letter Queue
  dead_letter_config {
    target_arn = aws_sqs_queue.attendance_dlq.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.attendance_lambda_vpc,
    aws_cloudwatch_log_group.attendance_reporter
  ]

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-attendance-reporter"
    Component = "attendance"
    Purpose   = "attendance-reporting"
  })
}

# =============================================================================
# Dead Letter Queue for Error Handling
# =============================================================================

resource "aws_sqs_queue" "attendance_dlq" {
  name                      = "${var.project_name}-${var.environment}-attendance-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-attendance-dlq"
    Component = "attendance"
    Purpose   = "error-handling"
  })
}

# =============================================================================
# EventBridge Rule for Scheduled Reports
# =============================================================================

resource "aws_cloudwatch_event_rule" "attendance_report" {
  name                = "${var.project_name}-${var.environment}-attendance-report"
  description         = "Trigger attendance report generation"
  schedule_expression = var.report_schedule_expression

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-attendance-report-rule"
    Component = "attendance"
    Purpose   = "scheduled-reporting"
  })
}

resource "aws_cloudwatch_event_target" "attendance_report" {
  rule      = aws_cloudwatch_event_rule.attendance_report.name
  target_id = "AttendanceReportTarget"
  arn       = aws_lambda_function.attendance_reporter.arn

  input = jsonencode({
    reportType = "daily"
    automated  = true
  })
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.attendance_reporter.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.attendance_report.arn
}