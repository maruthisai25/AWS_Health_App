# =============================================================================
# SNS Topics and Subscriptions
# =============================================================================

# =============================================================================
# SNS Topics
# =============================================================================

resource "aws_sns_topic" "notification_topics" {
  for_each = var.notification_topics

  name         = "${var.project_name}-${var.environment}-${each.key}"
  display_name = each.value.display_name

  # Enable encryption if specified
  kms_master_key_id = var.enable_notification_encryption ? var.kms_key_arn : null

  # Delivery policy for retries
  delivery_policy = jsonencode({
    "http" = {
      "defaultHealthyRetryPolicy" = {
        "minDelayTarget"     = 20
        "maxDelayTarget"     = 20
        "numRetries"         = 3
        "numMaxDelayRetries" = 0
        "numMinDelayRetries" = 0
        "numNoDelayRetries"  = 0
        "backoffFunction"    = "linear"
      }
      "disableSubscriptionOverrides" = false
    }
  })

  tags = merge(var.tags, var.sns_tags, {
    Name        = "${var.project_name}-${var.environment}-${each.key}-topic"
    Purpose     = "notification-topic"
    TopicType   = each.key
    Description = each.value.description
    Module      = "notifications"
  })
}

# =============================================================================
# SNS Topic Policies
# =============================================================================

resource "aws_sns_topic_policy" "notification_topic_policies" {
  for_each = aws_sns_topic.notification_topics

  arn = each.value.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${each.key}-topic-policy"
    Statement = [
      {
        Sid    = "AllowPublishFromLambda"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_execution_role.arn
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = each.value.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowSubscriptionManagement"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_execution_role.arn
        }
        Action = [
          "SNS:Subscribe",
          "SNS:Unsubscribe",
          "SNS:ListSubscriptionsByTopic"
        ]
        Resource = each.value.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# =============================================================================
# Dead Letter Queue for Failed Notifications
# =============================================================================

resource "aws_sqs_queue" "dead_letter_queue" {
  count = var.enable_dead_letter_queue ? 1 : 0

  name                       = "${var.project_name}-${var.environment}-notifications-dlq"
  message_retention_seconds  = 1209600  # 14 days
  visibility_timeout_seconds = 300

  # Enable encryption if specified
  kms_master_key_id                 = var.enable_notification_encryption ? var.kms_key_arn : null
  kms_data_key_reuse_period_seconds = var.enable_notification_encryption ? 300 : null

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-notifications-dlq"
    Purpose     = "dead-letter-queue"
    Module      = "notifications"
    Description = "Dead letter queue for failed notification processing"
  })
}

resource "aws_sqs_queue_policy" "dead_letter_queue_policy" {
  count = var.enable_dead_letter_queue ? 1 : 0

  queue_url = aws_sqs_queue.dead_letter_queue[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "dead-letter-queue-policy"
    Statement = [
      {
        Sid    = "AllowSNSToSendMessage"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.dead_letter_queue[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = [for topic in aws_sns_topic.notification_topics : topic.arn]
          }
        }
      }
    ]
  })
}

# =============================================================================
# SNS Subscriptions for Lambda Functions
# =============================================================================

resource "aws_sns_topic_subscription" "lambda_notification_handler" {
  for_each = aws_sns_topic.notification_topics

  topic_arn = each.value.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.notification_handler.arn

  # Dead letter queue configuration
  redrive_policy = var.enable_dead_letter_queue ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter_queue[0].arn
  }) : null

  depends_on = [
    aws_lambda_permission.allow_sns_notification_handler
  ]
}

# =============================================================================
# Lambda Permissions for SNS
# =============================================================================

resource "aws_lambda_permission" "allow_sns_notification_handler" {
  for_each = aws_sns_topic.notification_topics

  statement_id  = "AllowExecutionFromSNS-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notification_handler.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = each.value.arn
}

# =============================================================================
# SNS Platform Applications (for Push Notifications)
# =============================================================================

# Note: Platform applications would be created here for mobile push notifications
# This would require platform-specific certificates/keys for iOS/Android
# For now, we'll create placeholder resources that can be configured later

resource "aws_sns_platform_application" "ios_app" {
  count = var.enable_cost_optimization ? 0 : 1  # Disable in cost optimization mode

  name                         = "${var.project_name}-${var.environment}-ios"
  platform                     = "APNS"
  platform_credential          = "dummy-certificate"  # Replace with actual certificate
  success_feedback_role_arn     = aws_iam_role.sns_feedback_role.arn
  failure_feedback_role_arn     = aws_iam_role.sns_feedback_role.arn
  success_feedback_sample_rate  = "100"
}

resource "aws_sns_platform_application" "android_app" {
  count = var.enable_cost_optimization ? 0 : 1  # Disable in cost optimization mode

  name                         = "${var.project_name}-${var.environment}-android"
  platform                     = "GCM"
  platform_credential          = "dummy-api-key"  # Replace with actual API key
  success_feedback_role_arn     = aws_iam_role.sns_feedback_role.arn
  failure_feedback_role_arn     = aws_iam_role.sns_feedback_role.arn
  success_feedback_sample_rate  = "100"
}

# =============================================================================
# SNS Feedback Role for Platform Applications
# =============================================================================

resource "aws_iam_role" "sns_feedback_role" {
  name = "${var.project_name}-${var.environment}-sns-feedback-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-sns-feedback-role"
    Purpose     = "sns-feedback"
    Module      = "notifications"
  })
}

resource "aws_iam_role_policy" "sns_feedback_policy" {
  name = "${var.project_name}-${var.environment}-sns-feedback-policy"
  role = aws_iam_role.sns_feedback_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:PutMetricFilter",
          "logs:PutRetentionPolicy"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/sns/*"
      }
    ]
  })
}

# =============================================================================
# CloudWatch Alarms for SNS Topics
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "sns_topic_failed_notifications" {
  for_each = var.enable_detailed_monitoring ? aws_sns_topic.notification_topics : {}

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-failed-notifications"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NumberOfNotificationsFailed"
  namespace           = "AWS/SNS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors failed notifications for ${each.key} topic"
  alarm_actions       = [aws_sns_topic.notification_topics["system"].arn]

  dimensions = {
    TopicName = each.value.name
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-${each.key}-failed-notifications-alarm"
    Purpose     = "monitoring"
    TopicType   = each.key
    Module      = "notifications"
  })
}

# =============================================================================
# Data Sources
# =============================================================================