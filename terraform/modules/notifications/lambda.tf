# =============================================================================
# Lambda Functions for Notification Processing
# =============================================================================

# =============================================================================
# Lambda Execution Role
# =============================================================================

resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-${var.environment}-notifications-lambda-role"

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

  tags = merge(var.tags, var.lambda_tags, {
    Name        = "${var.project_name}-${var.environment}-notifications-lambda-role"
    Purpose     = "lambda-execution"
    Module      = "notifications"
  })
}

# =============================================================================
# Lambda IAM Policies
# =============================================================================

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  count = var.enable_lambda_vpc ? 1 : 0

  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_policy" "sns_publish_policy" {
  name        = "${var.project_name}-${var.environment}-sns-publish-policy"
  description = "Policy for publishing to SNS topics"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish",
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:ListSubscriptionsByTopic",
          "sns:GetTopicAttributes"
        ]
        Resource = [for topic in aws_sns_topic.notification_topics : topic.arn]
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-sns-publish-policy"
    Purpose     = "sns-permissions"
    Module      = "notifications"
  })
}

resource "aws_iam_policy" "ses_send_policy" {
  name        = "${var.project_name}-${var.environment}-ses-send-policy"
  description = "Policy for sending emails via SES"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
          "ses:SendTemplatedEmail",
          "ses:GetSendQuota",
          "ses:GetSendStatistics",
          "ses:ListTemplates",
          "ses:GetTemplate"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-ses-send-policy"
    Purpose     = "ses-permissions"
    Module      = "notifications"
  })
}

resource "aws_iam_policy" "dynamodb_notifications_policy" {
  name        = "${var.project_name}-${var.environment}-dynamodb-notifications-policy"
  description = "Policy for accessing notification preferences DynamoDB table"

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
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.notification_preferences.arn,
          "${aws_dynamodb_table.notification_preferences.arn}/index/*"
        ]
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-dynamodb-notifications-policy"
    Purpose     = "dynamodb-permissions"
    Module      = "notifications"
  })
}

resource "aws_iam_policy" "cognito_read_policy" {
  name        = "${var.project_name}-${var.environment}-cognito-read-policy"
  description = "Policy for reading user information from Cognito"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:AdminGetUser",
          "cognito-idp:ListUsers",
          "cognito-idp:AdminListGroupsForUser"
        ]
        Resource = var.user_pool_id != "" ? "arn:aws:cognito-idp:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:userpool/${var.user_pool_id}" : "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-cognito-read-policy"
    Purpose     = "cognito-permissions"
    Module      = "notifications"
  })
}

resource "aws_iam_policy" "kms_decrypt_policy" {
  count = var.enable_notification_encryption ? 1 : 0

  name        = "${var.project_name}-${var.environment}-kms-decrypt-policy"
  description = "Policy for decrypting notification data"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-kms-decrypt-policy"
    Purpose     = "kms-permissions"
    Module      = "notifications"
  })
}

# Attach policies to Lambda execution role
resource "aws_iam_role_policy_attachment" "sns_publish_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.sns_publish_policy.arn
}

resource "aws_iam_role_policy_attachment" "ses_send_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.ses_send_policy.arn
}

resource "aws_iam_role_policy_attachment" "dynamodb_notifications_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.dynamodb_notifications_policy.arn
}

resource "aws_iam_role_policy_attachment" "cognito_read_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.cognito_read_policy.arn
}

resource "aws_iam_role_policy_attachment" "kms_decrypt_attachment" {
  count = var.enable_notification_encryption ? 1 : 0

  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.kms_decrypt_policy[0].arn
}

# =============================================================================
# Security Group for Lambda Functions
# =============================================================================

resource "aws_security_group" "lambda_sg" {
  count = var.enable_lambda_vpc ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-notifications-lambda-"
  vpc_id      = var.vpc_id
  description = "Security group for notifications Lambda functions"

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
    Name        = "${var.project_name}-${var.environment}-notifications-lambda-sg"
    Purpose     = "lambda-security"
    Module      = "notifications"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# CloudWatch Log Groups
# =============================================================================

resource "aws_cloudwatch_log_group" "notification_handler" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-notification-handler"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-notification-handler-logs"
    Purpose     = "lambda-logging"
    Function    = "notification-handler"
    Module      = "notifications"
  })
}

resource "aws_cloudwatch_log_group" "email_sender" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-email-sender"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-email-sender-logs"
    Purpose     = "lambda-logging"
    Function    = "email-sender"
    Module      = "notifications"
  })
}

# =============================================================================
# Lambda Functions
# =============================================================================

resource "aws_lambda_function" "notification_handler" {
  filename         = "${path.module}/../../../applications/lambda-functions/notification-handler/notification-handler.zip"
  function_name    = "${var.project_name}-${var.environment}-notification-handler"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  reserved_concurrent_executions = var.lambda_reserved_concurrency

  # VPC configuration
  dynamic "vpc_config" {
    for_each = var.enable_lambda_vpc ? [1] : []
    content {
      subnet_ids         = var.private_subnet_ids
      security_group_ids = [aws_security_group.lambda_sg[0].id]
    }
  }

  # Environment variables
  environment {
    variables = merge({
      PROJECT_NAME                = var.project_name
      ENVIRONMENT                = var.environment
      SNS_TOPICS                 = jsonencode({
        for topic_name, topic in aws_sns_topic.notification_topics : topic_name => topic.arn
      })
      SES_FROM_EMAIL             = var.ses_from_email
      SES_FROM_NAME              = var.ses_from_name
      SES_CONFIGURATION_SET      = aws_ses_configuration_set.main.name
      NOTIFICATION_PREFERENCES_TABLE = aws_dynamodb_table.notification_preferences.name
      USER_POOL_ID               = var.user_pool_id
      RATE_LIMIT_PER_MINUTE      = tostring(var.rate_limit_per_minute)
      BATCH_SIZE                 = tostring(var.notification_batch_size)
      KMS_KEY_ARN                = var.enable_notification_encryption ? var.kms_key_arn : ""
    }, var.lambda_environment_variables)
  }

  # X-Ray tracing
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = merge(var.tags, var.lambda_tags, {
    Name        = "${var.project_name}-${var.environment}-notification-handler"
    Purpose     = "notification-processing"
    Function    = "notification-handler"
    Module      = "notifications"
  })

  depends_on = [
    aws_cloudwatch_log_group.notification_handler,
    data.archive_file.notification_handler_zip
  ]
}

resource "aws_lambda_function" "email_sender" {
  filename         = "${path.module}/../../../applications/lambda-functions/email-sender/email-sender.zip"
  function_name    = "${var.project_name}-${var.environment}-email-sender"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  reserved_concurrent_executions = var.lambda_reserved_concurrency

  # VPC configuration
  dynamic "vpc_config" {
    for_each = var.enable_lambda_vpc ? [1] : []
    content {
      subnet_ids         = var.private_subnet_ids
      security_group_ids = [aws_security_group.lambda_sg[0].id]
    }
  }

  # Environment variables
  environment {
    variables = merge({
      PROJECT_NAME                = var.project_name
      ENVIRONMENT                = var.environment
      SES_FROM_EMAIL             = var.ses_from_email
      SES_FROM_NAME              = var.ses_from_name
      SES_CONFIGURATION_SET      = aws_ses_configuration_set.main.name
      EMAIL_TEMPLATES            = jsonencode({
        for template_name, template in aws_ses_template.email_templates : template_name => template.name
      })
      NOTIFICATION_PREFERENCES_TABLE = aws_dynamodb_table.notification_preferences.name
      USER_POOL_ID               = var.user_pool_id
      KMS_KEY_ARN                = var.enable_notification_encryption ? var.kms_key_arn : ""
    }, var.lambda_environment_variables)
  }

  # X-Ray tracing
  tracing_config {
    mode = var.enable_xray_tracing ? "Active" : "PassThrough"
  }

  tags = merge(var.tags, var.lambda_tags, {
    Name        = "${var.project_name}-${var.environment}-email-sender"
    Purpose     = "email-sending"
    Function    = "email-sender"
    Module      = "notifications"
  })

  depends_on = [
    aws_cloudwatch_log_group.email_sender,
    data.archive_file.email_sender_zip
  ]
}

# =============================================================================
# Lambda Function ZIP Files
# =============================================================================

data "archive_file" "notification_handler_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../applications/lambda-functions/notification-handler"
  output_path = "${path.module}/../../../applications/lambda-functions/notification-handler/notification-handler.zip"
  excludes    = ["notification-handler.zip", "node_modules", ".git"]
}

data "archive_file" "email_sender_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../applications/lambda-functions/email-sender"
  output_path = "${path.module}/../../../applications/lambda-functions/email-sender/email-sender.zip"
  excludes    = ["email-sender.zip", "node_modules", ".git"]
}

# =============================================================================
# DynamoDB Table for Notification Preferences
# =============================================================================

resource "aws_dynamodb_table" "notification_preferences" {
  name           = "${var.project_name}-${var.environment}-notification-preferences"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "notification_type"
    type = "S"
  }

  global_secondary_index {
    name            = "NotificationTypeIndex"
    hash_key        = "notification_type"
    projection_type = "ALL"
  }

  # Enable encryption if specified
  dynamic "server_side_encryption" {
    for_each = var.enable_notification_encryption ? [1] : []
    content {
      enabled     = true
      kms_key_arn = var.kms_key_arn
    }
  }

  # TTL for automatic cleanup of old preferences
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-notification-preferences"
    Purpose     = "notification-preferences"
    Module      = "notifications"
  })
}

# =============================================================================
# CloudWatch Alarms for Lambda Functions
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "notification_handler_errors" {
  count = var.enable_detailed_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-notification-handler-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors notification handler errors"
  alarm_actions       = [aws_sns_topic.notification_topics["system"].arn]

  dimensions = {
    FunctionName = aws_lambda_function.notification_handler.function_name
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-notification-handler-errors-alarm"
    Purpose     = "monitoring"
    Function    = "notification-handler"
    Module      = "notifications"
  })
}

resource "aws_cloudwatch_metric_alarm" "email_sender_errors" {
  count = var.enable_detailed_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-email-sender-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors email sender errors"
  alarm_actions       = [aws_sns_topic.notification_topics["system"].arn]

  dimensions = {
    FunctionName = aws_lambda_function.email_sender.function_name
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-email-sender-errors-alarm"
    Purpose     = "monitoring"
    Function    = "email-sender"
    Module      = "notifications"
  })
}

# =============================================================================
# CloudWatch Dashboard
# =============================================================================

resource "aws_cloudwatch_dashboard" "notifications" {
  dashboard_name = "${var.project_name}-${var.environment}-notifications"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.notification_handler.function_name],
            [".", "Errors", ".", "."],
            [".", "Duration", ".", "."],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.email_sender.function_name],
            [".", "Errors", ".", "."],
            [".", "Duration", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda Function Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            for topic_name, topic in aws_sns_topic.notification_topics : [
              "AWS/SNS", "NumberOfMessagesPublished", "TopicName", topic.name
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "SNS Topic Messages"
          period  = 300
        }
      }
    ]
  })
}

# =============================================================================
# Data Sources
# =============================================================================