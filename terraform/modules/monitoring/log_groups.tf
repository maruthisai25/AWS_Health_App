# =============================================================================
# CloudWatch Log Groups Configuration
# =============================================================================

# =============================================================================
# Standard Log Groups
# =============================================================================

# Application logs
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/application/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "/aws/application/${local.name_prefix}"
    Purpose     = "application-logs"
    Module      = "monitoring"
    LogType     = "application"
  })
}

# Security logs
resource "aws_cloudwatch_log_group" "security" {
  name              = "/aws/security/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "/aws/security/${local.name_prefix}"
    Purpose     = "security-logs"
    Module      = "monitoring"
    LogType     = "security"
  })
}

# Performance logs
resource "aws_cloudwatch_log_group" "performance" {
  name              = "/aws/performance/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "/aws/performance/${local.name_prefix}"
    Purpose     = "performance-logs"
    Module      = "monitoring"
    LogType     = "performance"
  })
}

# API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gateway_access" {
  count             = var.api_gateway_id != "" ? 1 : 0
  name              = "/aws/apigateway/${local.name_prefix}/access"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "/aws/apigateway/${local.name_prefix}/access"
    Purpose     = "api-gateway-access-logs"
    Module      = "monitoring"
    LogType     = "access"
  })
}

# API Gateway execution logs
resource "aws_cloudwatch_log_group" "api_gateway_execution" {
  count             = var.api_gateway_id != "" ? 1 : 0
  name              = "/aws/apigateway/${local.name_prefix}/execution"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "/aws/apigateway/${local.name_prefix}/execution"
    Purpose     = "api-gateway-execution-logs"
    Module      = "monitoring"
    LogType     = "execution"
  })
}

# Lambda function logs (individual log groups for each function)
resource "aws_cloudwatch_log_group" "lambda_functions" {
  for_each          = toset(var.lambda_function_names)
  name              = "/aws/lambda/${each.value}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "/aws/lambda/${each.value}"
    Purpose     = "lambda-logs"
    Module      = "monitoring"
    LogType     = "lambda"
    Function    = each.value
  })
}

# RDS logs (if RDS cluster is specified)
resource "aws_cloudwatch_log_group" "rds_error" {
  count             = var.rds_cluster_identifier != "" ? 1 : 0
  name              = "/aws/rds/cluster/${var.rds_cluster_identifier}/error"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "/aws/rds/cluster/${var.rds_cluster_identifier}/error"
    Purpose     = "rds-error-logs"
    Module      = "monitoring"
    LogType     = "rds-error"
  })
}

resource "aws_cloudwatch_log_group" "rds_general" {
  count             = var.rds_cluster_identifier != "" ? 1 : 0
  name              = "/aws/rds/cluster/${var.rds_cluster_identifier}/general"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "/aws/rds/cluster/${var.rds_cluster_identifier}/general"
    Purpose     = "rds-general-logs"
    Module      = "monitoring"
    LogType     = "rds-general"
  })
}

resource "aws_cloudwatch_log_group" "rds_slowquery" {
  count             = var.rds_cluster_identifier != "" ? 1 : 0
  name              = "/aws/rds/cluster/${var.rds_cluster_identifier}/slowquery"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "/aws/rds/cluster/${var.rds_cluster_identifier}/slowquery"
    Purpose     = "rds-slowquery-logs"
    Module      = "monitoring"
    LogType     = "rds-slowquery"
  })
}

# VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count             = var.vpc_id != "" ? 1 : 0
  name              = "/aws/vpc/flowlogs/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "/aws/vpc/flowlogs/${local.name_prefix}"
    Purpose     = "vpc-flow-logs"
    Module      = "monitoring"
    LogType     = "vpc-flow"
  })
}

# Custom log groups (from variables)
resource "aws_cloudwatch_log_group" "custom" {
  for_each          = var.custom_log_groups
  name              = "/aws/custom/${local.name_prefix}/${each.key}"
  retention_in_days = each.value.retention_in_days
  kms_key_id        = each.value.kms_key_id

  tags = merge(var.tags, {
    Name        = "/aws/custom/${local.name_prefix}/${each.key}"
    Purpose     = "custom-logs"
    Module      = "monitoring"
    LogType     = "custom"
    CustomType  = each.key
  })
}

# =============================================================================
# Log Metric Filters for Application Monitoring
# =============================================================================

# Application error rate
resource "aws_cloudwatch_log_metric_filter" "application_errors" {
  name           = "${local.name_prefix}-application-errors"
  log_group_name = aws_cloudwatch_log_group.application.name
  pattern        = "[timestamp, request_id, level=\"ERROR\", message]"

  metric_transformation {
    name      = "ApplicationErrorCount"
    namespace = "${var.project_name}/Application"
    value     = "1"
    
    default_value = "0"
  }
}

# Application warning rate
resource "aws_cloudwatch_log_metric_filter" "application_warnings" {
  name           = "${local.name_prefix}-application-warnings"
  log_group_name = aws_cloudwatch_log_group.application.name
  pattern        = "[timestamp, request_id, level=\"WARN\", message]"

  metric_transformation {
    name      = "ApplicationWarningCount"
    namespace = "${var.project_name}/Application"
    value     = "1"
    
    default_value = "0"
  }
}

# Security events
resource "aws_cloudwatch_log_metric_filter" "security_events" {
  name           = "${local.name_prefix}-security-events"
  log_group_name = aws_cloudwatch_log_group.security.name
  pattern        = "[timestamp, request_id, level, event_type=\"SECURITY_EVENT\", message]"

  metric_transformation {
    name      = "SecurityEventCount"
    namespace = "${var.project_name}/Security"
    value     = "1"
    
    default_value = "0"
  }
}

# Performance issues
resource "aws_cloudwatch_log_metric_filter" "performance_issues" {
  name           = "${local.name_prefix}-performance-issues"
  log_group_name = aws_cloudwatch_log_group.performance.name
  pattern        = "[timestamp, request_id, level, metric_type=\"SLOW_QUERY\" || metric_type=\"HIGH_LATENCY\", message]"

  metric_transformation {
    name      = "PerformanceIssueCount"
    namespace = "${var.project_name}/Performance"
    value     = "1"
    
    default_value = "0"
  }
}

# API Gateway 4XX errors
resource "aws_cloudwatch_log_metric_filter" "api_gateway_4xx" {
  count          = var.api_gateway_id != "" ? 1 : 0
  name           = "${local.name_prefix}-api-gateway-4xx"
  log_group_name = aws_cloudwatch_log_group.api_gateway_access[0].name
  pattern        = "[timestamp, request_id, ip, user, timestamp, method, resource, protocol, status=4*, size, referer, agent]"

  metric_transformation {
    name      = "ApiGateway4XXCount"
    namespace = "${var.project_name}/ApiGateway"
    value     = "1"
    
    default_value = "0"
  }
}

# API Gateway 5XX errors
resource "aws_cloudwatch_log_metric_filter" "api_gateway_5xx" {
  count          = var.api_gateway_id != "" ? 1 : 0
  name           = "${local.name_prefix}-api-gateway-5xx"
  log_group_name = aws_cloudwatch_log_group.api_gateway_access[0].name
  pattern        = "[timestamp, request_id, ip, user, timestamp, method, resource, protocol, status=5*, size, referer, agent]"

  metric_transformation {
    name      = "ApiGateway5XXCount"
    namespace = "${var.project_name}/ApiGateway"
    value     = "1"
    
    default_value = "0"
  }
}

# =============================================================================
# CloudWatch Alarms for Log-based Metrics
# =============================================================================

# Application error rate alarm
resource "aws_cloudwatch_metric_alarm" "application_error_rate" {
  alarm_name          = "${local.name_prefix}-application-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApplicationErrorCount"
  namespace           = "${var.project_name}/Application"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "High application error rate detected"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-application-error-rate"
    Purpose     = "application-error-monitoring"
    Module      = "monitoring"
  })
}

# Security events alarm
resource "aws_cloudwatch_metric_alarm" "security_events" {
  alarm_name          = "${local.name_prefix}-security-events"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "SecurityEventCount"
  namespace           = "${var.project_name}/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Security event detected"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-security-events"
    Purpose     = "security-event-monitoring"
    Module      = "monitoring"
  })
}

# Performance issues alarm
resource "aws_cloudwatch_metric_alarm" "performance_issues" {
  alarm_name          = "${local.name_prefix}-performance-issues"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "PerformanceIssueCount"
  namespace           = "${var.project_name}/Performance"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Performance issues detected"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-performance-issues"
    Purpose     = "performance-monitoring"
    Module      = "monitoring"
  })
}

# =============================================================================
# CloudWatch Logs Insights Saved Queries
# =============================================================================

resource "aws_logs_query_definition" "saved_queries" {
  count = var.enable_log_insights_queries ? length(local.saved_queries) : 0

  name = local.saved_queries[count.index].name

  log_group_names = local.saved_queries[count.index].log_groups

  query_string = local.saved_queries[count.index].query

  tags = merge(var.tags, {
    Name        = local.saved_queries[count.index].name
    Purpose     = "log-insights-query"
    Module      = "monitoring"
    QueryType   = local.saved_queries[count.index].type
  })
}

# Local values for saved queries
locals {
  saved_queries = [
    {
      name = "${local.name_prefix}-error-analysis"
      type = "error-analysis"
      log_groups = [
        aws_cloudwatch_log_group.application.name
      ]
      query = <<EOF
fields @timestamp, @message
| filter @message like /ERROR/
| stats count() by bin(5m)
| sort @timestamp desc
EOF
    },
    {
      name = "${local.name_prefix}-slow-requests"
      type = "performance-analysis"
      log_groups = [
        aws_cloudwatch_log_group.performance.name
      ]
      query = <<EOF
fields @timestamp, @message
| filter @message like /SLOW/ or @message like /HIGH_LATENCY/
| stats count() by bin(5m)
| sort @timestamp desc
EOF
    },
    {
      name = "${local.name_prefix}-security-events"
      type = "security-analysis"
      log_groups = [
        aws_cloudwatch_log_group.security.name
      ]
      query = <<EOF
fields @timestamp, @message
| filter @message like /SECURITY_EVENT/
| stats count() by bin(1h)
| sort @timestamp desc
EOF
    },
    {
      name = "${local.name_prefix}-lambda-errors"
      type = "lambda-analysis"
      log_groups = [for func in var.lambda_function_names : "/aws/lambda/${func}"]
      query = <<EOF
fields @timestamp, @requestId, @message
| filter @type = "REPORT"
| stats count() by bin(5m)
| sort @timestamp desc
EOF
    },
    {
      name = "${local.name_prefix}-api-gateway-analysis"
      type = "api-analysis"
      log_groups = var.api_gateway_id != "" ? [
        aws_cloudwatch_log_group.api_gateway_access[0].name,
        aws_cloudwatch_log_group.api_gateway_execution[0].name
      ] : []
      query = <<EOF
fields @timestamp, @message
| filter @message like /ERROR/ or @message like /4\d\d/ or @message like /5\d\d/
| stats count() by bin(5m)
| sort @timestamp desc
EOF
    }
  ]
}

# =============================================================================
# Log Stream Configuration for Real-time Monitoring
# =============================================================================

# CloudWatch Log Destination for cross-account log sharing (if needed)
resource "aws_cloudwatch_log_destination" "cross_account" {
  count           = var.environment == "prod" ? 1 : 0
  name            = "${local.name_prefix}-cross-account-logs"
  role_arn        = aws_iam_role.log_destination[0].arn
  target_arn      = aws_kinesis_stream.log_stream[0].arn

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-cross-account-logs"
    Purpose     = "cross-account-log-sharing"
    Module      = "monitoring"
  })
}

# Kinesis stream for log processing (production only)
resource "aws_kinesis_stream" "log_stream" {
  count           = var.environment == "prod" ? 1 : 0
  name            = "${local.name_prefix}-log-stream"
  shard_count     = 1
  retention_period = 24

  shard_level_metrics = [
    "IncomingRecords",
    "OutgoingRecords",
  ]

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-log-stream"
    Purpose     = "log-processing"
    Module      = "monitoring"
  })
}

# IAM role for log destination
resource "aws_iam_role" "log_destination" {
  count = var.environment == "prod" ? 1 : 0
  name  = "${local.name_prefix}-log-destination-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-log-destination-role"
    Purpose     = "log-destination-permissions"
    Module      = "monitoring"
  })
}

resource "aws_iam_role_policy" "log_destination" {
  count = var.environment == "prod" ? 1 : 0
  name  = "${local.name_prefix}-log-destination-policy"
  role  = aws_iam_role.log_destination[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = aws_kinesis_stream.log_stream[0].arn
      }
    ]
  })
}