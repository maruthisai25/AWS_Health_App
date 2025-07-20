# =============================================================================
# X-Ray Distributed Tracing Configuration
# =============================================================================

# =============================================================================
# X-Ray Encryption Configuration
# =============================================================================

resource "aws_xray_encryption_config" "main" {
  count = var.enable_xray_tracing ? 1 : 0
  type  = "NONE"  # Use "KMS" for KMS encryption if needed

  # Uncomment and provide KMS key ID for encryption
  # key_id = var.kms_key_id
}

# =============================================================================
# X-Ray Sampling Rule
# =============================================================================

resource "aws_xray_sampling_rule" "main" {
  count = var.enable_xray_tracing ? 1 : 0

  rule_name      = "${local.name_prefix}-sampling-rule"
  priority       = 9000
  version        = 1
  reservoir_size = 1
  fixed_rate     = var.xray_sampling_rate
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-xray-sampling-rule"
    Purpose     = "xray-sampling"
    Module      = "monitoring"
  })
}

# =============================================================================
# X-Ray Service Map and Insights
# =============================================================================

# CloudWatch Log Group for X-Ray Insights
resource "aws_cloudwatch_log_group" "xray_insights" {
  count             = var.enable_xray_tracing ? 1 : 0
  name              = "/aws/xray/insights/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "/aws/xray/insights/${local.name_prefix}"
    Purpose     = "xray-insights-logs"
    Module      = "monitoring"
  })
}

# =============================================================================
# CloudWatch Alarms for X-Ray
# =============================================================================

# High trace error rate alarm
resource "aws_cloudwatch_metric_alarm" "xray_high_error_rate" {
  count = var.enable_xray_tracing && var.enable_high_error_rate_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-xray-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ErrorRate"
  namespace           = "AWS/X-Ray"
  period              = "300"
  statistic           = "Average"
  threshold           = var.error_rate_threshold
  alarm_description   = "High error rate detected in X-Ray traces"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    ServiceName = var.project_name
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-xray-high-error-rate"
    Purpose     = "xray-error-monitoring"
    Module      = "monitoring"
  })
}

# High response time alarm
resource "aws_cloudwatch_metric_alarm" "xray_high_response_time" {
  count = var.enable_xray_tracing && var.enable_high_latency_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-xray-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ResponseTime"
  namespace           = "AWS/X-Ray"
  period              = "300"
  statistic           = "Average"
  threshold           = var.latency_threshold_ms / 1000  # Convert to seconds
  alarm_description   = "High response time detected in X-Ray traces"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    ServiceName = var.project_name
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-xray-high-response-time"
    Purpose     = "xray-latency-monitoring"
    Module      = "monitoring"
  })
}

# =============================================================================
# X-Ray Service Map Dashboard Widget (for inclusion in main dashboard)
# =============================================================================

locals {
  xray_dashboard_widget = var.enable_xray_tracing ? {
    type   = "metric"
    x      = 0
    y      = 30
    width  = 24
    height = 6
    properties = {
      metrics = [
        ["AWS/X-Ray", "TracesReceived"],
        [".", "TracesProcessed"],
        [".", "LatencyHigh", "ServiceName", var.project_name],
        [".", "ErrorRate", ".", "."],
        [".", "ResponseTime", ".", "."]
      ]
      view    = "timeSeries"
      stacked = false
      region  = data.aws_region.current.name
      title   = "X-Ray Distributed Tracing Metrics"
      period  = 300
      annotations = {
        horizontal = [
          {
            label = "Error Rate Threshold"
            value = var.error_rate_threshold
          },
          {
            label = "Response Time Threshold (seconds)"
            value = var.latency_threshold_ms / 1000
          }
        ]
      }
    }
  } : null
}

# =============================================================================
# X-Ray Insights Queries (for common debugging scenarios)
# =============================================================================

resource "aws_logs_query_definition" "xray_error_analysis" {
  count = var.enable_xray_tracing && var.enable_log_insights_queries ? 1 : 0

  name = "${local.name_prefix}-xray-error-analysis"

  log_group_names = [
    aws_cloudwatch_log_group.xray_insights[0].name
  ]

  query_string = <<EOF
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by bin(5m)
| sort @timestamp desc
EOF

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-xray-error-analysis"
    Purpose     = "xray-error-analysis"
    Module      = "monitoring"
  })
}

resource "aws_logs_query_definition" "xray_slow_requests" {
  count = var.enable_xray_tracing && var.enable_log_insights_queries ? 1 : 0

  name = "${local.name_prefix}-xray-slow-requests"

  log_group_names = [
    aws_cloudwatch_log_group.xray_insights[0].name
  ]

  query_string = <<EOF
fields @timestamp, @message
| filter @message like /SLOW/
| stats count() by bin(5m)
| sort @timestamp desc
EOF

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-xray-slow-requests"
    Purpose     = "xray-performance-analysis"
    Module      = "monitoring"
  })
}

# =============================================================================
# IAM Role for X-Ray (if needed for custom applications)
# =============================================================================

data "aws_iam_policy_document" "xray_assume_role" {
  count = var.enable_xray_tracing ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "ec2.amazonaws.com", "ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "xray_role" {
  count              = var.enable_xray_tracing ? 1 : 0
  name               = "${local.name_prefix}-xray-role"
  assume_role_policy = data.aws_iam_policy_document.xray_assume_role[0].json

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-xray-role"
    Purpose     = "xray-tracing"
    Module      = "monitoring"
  })
}

resource "aws_iam_role_policy_attachment" "xray_write_only_access" {
  count      = var.enable_xray_tracing ? 1 : 0
  role       = aws_iam_role.xray_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# =============================================================================
# X-Ray Configuration for Lambda Functions (policy document)
# =============================================================================

data "aws_iam_policy_document" "lambda_xray_policy" {
  count = var.enable_xray_tracing ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries"
    ]
    resources = ["*"]
  }
}

# =============================================================================
# X-Ray Service Map Annotations (for better service identification)
# =============================================================================

locals {
  xray_annotations = var.enable_xray_tracing ? {
    environment = var.environment
    project     = var.project_name
    version     = "1.0"
  } : {}
}

# =============================================================================
# X-Ray Subsegment Configuration for Different Services
# =============================================================================

locals {
  xray_subsegments = var.enable_xray_tracing ? {
    # API Gateway subsegments
    api_gateway = {
      name        = "api-gateway"
      namespace   = "remote"
      annotations = local.xray_annotations
    }
    
    # Lambda subsegments
    lambda = {
      name        = "lambda-functions"
      namespace   = "aws"
      annotations = merge(local.xray_annotations, {
        service_type = "lambda"
      })
    }
    
    # DynamoDB subsegments
    dynamodb = {
      name        = "dynamodb"
      namespace   = "aws"
      annotations = merge(local.xray_annotations, {
        service_type = "dynamodb"
      })
    }
    
    # RDS subsegments
    rds = {
      name        = "rds"
      namespace   = "aws"
      annotations = merge(local.xray_annotations, {
        service_type = "rds"
      })
    }
    
    # S3 subsegments
    s3 = {
      name        = "s3"
      namespace   = "aws"
      annotations = merge(local.xray_annotations, {
        service_type = "s3"
      })
    }
  } : {}
}

# =============================================================================
# X-Ray Custom Metrics for Business Logic
# =============================================================================

resource "aws_cloudwatch_log_metric_filter" "xray_business_errors" {
  count          = var.enable_xray_tracing ? 1 : 0
  name           = "${local.name_prefix}-xray-business-errors"
  log_group_name = aws_cloudwatch_log_group.xray_insights[0].name
  pattern        = "[timestamp, request_id, level=\"ERROR\", message]"

  metric_transformation {
    name      = "BusinessErrorCount"
    namespace = "${var.project_name}/XRay"
    value     = "1"
    
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "xray_business_errors" {
  count = var.enable_xray_tracing ? 1 : 0

  alarm_name          = "${local.name_prefix}-xray-business-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BusinessErrorCount"
  namespace           = "${var.project_name}/XRay"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "High business error rate detected in X-Ray traces"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-xray-business-errors"
    Purpose     = "xray-business-monitoring"
    Module      = "monitoring"
  })
}