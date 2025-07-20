# =============================================================================
# CloudWatch Dashboards and Alarms
# =============================================================================

# Local values
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  dashboard_name = var.dashboard_name != "" ? var.dashboard_name : "${local.name_prefix}-dashboard"
}

# =============================================================================
# SNS Topics for Notifications
# =============================================================================

resource "aws_sns_topic" "alarms" {
  name = "${local.name_prefix}-alarms"

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-alarms"
    Purpose     = "alarm-notifications"
    Module      = "monitoring"
  })
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.alarm_notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_notification_email
}

resource "aws_sns_topic" "cost_alerts" {
  count = var.enable_cost_monitoring ? 1 : 0
  name  = "${local.name_prefix}-cost-alerts"

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-cost-alerts"
    Purpose     = "cost-notifications"
    Module      = "monitoring"
  })
}

resource "aws_sns_topic_subscription" "cost_email_alerts" {
  count     = var.enable_cost_monitoring && var.alarm_notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.cost_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alarm_notification_email
}

# =============================================================================
# CloudWatch Dashboard
# =============================================================================

resource "aws_cloudwatch_dashboard" "main" {
  count          = var.enable_detailed_monitoring ? 1 : 0
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      # API Gateway Metrics
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = var.api_gateway_id != "" ? [
            ["AWS/ApiGateway", "Count", "ApiName", var.api_gateway_id, "Stage", var.api_gateway_stage_name],
            [".", "Latency", ".", ".", ".", "."],
            [".", "4XXError", ".", ".", ".", "."],
            [".", "5XXError", ".", ".", ".", "."]
          ] : []
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "API Gateway Metrics"
          period  = 300
        }
      },
      # Lambda Function Metrics
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [for func in var.lambda_function_names : 
            ["AWS/Lambda", "Invocations", "FunctionName", func]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda Invocations"
          period  = 300
        }
      },
      # Lambda Error Metrics
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [for func in var.lambda_function_names : 
            ["AWS/Lambda", "Errors", "FunctionName", func]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda Errors"
          period  = 300
        }
      },
      # Lambda Duration Metrics
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [for func in var.lambda_function_names : 
            ["AWS/Lambda", "Duration", "FunctionName", func]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda Duration"
          period  = 300
        }
      },
      # DynamoDB Metrics
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = flatten([for table in var.dynamodb_table_names : [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", table],
            [".", "ConsumedWriteCapacityUnits", ".", table],
            [".", "ThrottledRequests", ".", table]
          ]])
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "DynamoDB Metrics"
          period  = 300
        }
      },
      # RDS Metrics
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = var.rds_cluster_identifier != "" ? [
            ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", var.rds_cluster_identifier],
            [".", "DatabaseConnections", ".", "."],
            [".", "ReadLatency", ".", "."],
            [".", "WriteLatency", ".", "."]
          ] : []
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "RDS Cluster Metrics"
          period  = 300
        }
      },
      # S3 Metrics
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          metrics = flatten([for bucket in var.s3_bucket_names : [
            ["AWS/S3", "BucketSizeBytes", "BucketName", bucket, "StorageType", "StandardStorage"],
            [".", "NumberOfObjects", ".", bucket, ".", "AllStorageTypes"]
          ]])
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "S3 Storage Metrics"
          period  = 86400
        }
      },
      # CloudFront Metrics
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          metrics = flatten([for dist in var.cloudfront_distribution_ids : [
            ["AWS/CloudFront", "Requests", "DistributionId", dist],
            [".", "BytesDownloaded", ".", dist],
            [".", "4xxErrorRate", ".", dist],
            [".", "5xxErrorRate", ".", dist]
          ]])
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"  # CloudFront metrics are always in us-east-1
          title   = "CloudFront Metrics"
          period  = 300
        }
      },
      # Application Load Balancer Metrics
      {
        type   = "metric"
        x      = 0
        y      = 24
        width  = 12
        height = 6
        properties = {
          metrics = var.alb_arn_suffix != "" ? [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix],
            [".", "TargetResponseTime", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ] : []
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Application Load Balancer Metrics"
          period  = 300
        }
      },
      # OpenSearch Metrics
      {
        type   = "metric"
        x      = 12
        y      = 24
        width  = 12
        height = 6
        properties = {
          metrics = var.opensearch_domain_name != "" ? [
            ["AWS/ES", "CPUUtilization", "DomainName", var.opensearch_domain_name, "ClientId", data.aws_caller_identity.current.account_id],
            [".", "JVMMemoryPressure", ".", ".", ".", "."],
            [".", "SearchLatency", ".", ".", ".", "."],
            [".", "IndexingLatency", ".", ".", ".", "."]
          ] : []
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "OpenSearch Metrics"
          period  = 300
        }
      }
    ]
  })
}

# =============================================================================
# CloudWatch Alarms - Lambda Functions
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = var.enable_high_error_rate_alarms ? toset(var.lambda_function_names) : toset([])

  alarm_name          = "${local.name_prefix}-lambda-${each.value}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors lambda errors for ${each.value}"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    FunctionName = each.value
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-lambda-${each.value}-errors"
    Purpose     = "lambda-error-monitoring"
    Module      = "monitoring"
  })
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = var.enable_high_latency_alarms ? toset(var.lambda_function_names) : toset([])

  alarm_name          = "${local.name_prefix}-lambda-${each.value}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = var.latency_threshold_ms
  alarm_description   = "This metric monitors lambda duration for ${each.value}"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    FunctionName = each.value
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-lambda-${each.value}-duration"
    Purpose     = "lambda-duration-monitoring"
    Module      = "monitoring"
  })
}

# =============================================================================
# CloudWatch Alarms - API Gateway
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "api_gateway_errors" {
  count = var.enable_high_error_rate_alarms && var.api_gateway_id != "" ? 1 : 0

  alarm_name          = "${local.name_prefix}-api-gateway-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors API Gateway 4XX errors"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    ApiName = var.api_gateway_id
    Stage   = var.api_gateway_stage_name
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-api-gateway-errors"
    Purpose     = "api-gateway-error-monitoring"
    Module      = "monitoring"
  })
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_latency" {
  count = var.enable_high_latency_alarms && var.api_gateway_id != "" ? 1 : 0

  alarm_name          = "${local.name_prefix}-api-gateway-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = var.latency_threshold_ms
  alarm_description   = "This metric monitors API Gateway latency"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    ApiName = var.api_gateway_id
    Stage   = var.api_gateway_stage_name
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-api-gateway-latency"
    Purpose     = "api-gateway-latency-monitoring"
    Module      = "monitoring"
  })
}

# =============================================================================
# CloudWatch Alarms - DynamoDB
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  for_each = toset(var.dynamodb_table_names)

  alarm_name          = "${local.name_prefix}-dynamodb-${each.value}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors DynamoDB throttles for ${each.value}"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    TableName = each.value
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-dynamodb-${each.value}-throttles"
    Purpose     = "dynamodb-throttle-monitoring"
    Module      = "monitoring"
  })
}

# =============================================================================
# CloudWatch Alarms - RDS
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count = var.rds_cluster_identifier != "" ? 1 : 0

  alarm_name          = "${local.name_prefix}-rds-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBClusterIdentifier = var.rds_cluster_identifier
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-rds-cpu-utilization"
    Purpose     = "rds-cpu-monitoring"
    Module      = "monitoring"
  })
}

# =============================================================================
# CloudWatch Alarms - Application Load Balancer
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  count = var.enable_high_latency_alarms && var.alb_arn_suffix != "" ? 1 : 0

  alarm_name          = "${local.name_prefix}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = var.latency_threshold_ms / 1000  # Convert to seconds
  alarm_description   = "This metric monitors ALB response time"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-alb-response-time"
    Purpose     = "alb-latency-monitoring"
    Module      = "monitoring"
  })
}

# =============================================================================
# Cost Monitoring
# =============================================================================

resource "aws_budgets_budget" "monthly" {
  count = var.enable_cost_monitoring ? 1 : 0

  name         = "${local.name_prefix}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  cost_filter {
    name   = "Tag:Project"
    values = [var.project_name]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = var.alarm_notification_email != "" ? [var.alarm_notification_email] : []
    subscriber_sns_topic_arns  = [aws_sns_topic.cost_alerts[0].arn]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alarm_notification_email != "" ? [var.alarm_notification_email] : []
    subscriber_sns_topic_arns  = [aws_sns_topic.cost_alerts[0].arn]
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-monthly-budget"
    Purpose     = "cost-monitoring"
    Module      = "monitoring"
  })
}

# =============================================================================
# Cost Anomaly Detection
# =============================================================================

resource "aws_ce_anomaly_detector" "main" {
  count = var.enable_cost_anomaly_detection ? 1 : 0

  name         = "${local.name_prefix}-cost-anomaly-detector"
  monitor_type = "DIMENSIONAL"

  specification = jsonencode({
    Dimension = "SERVICE"
    MatchOptions = ["EQUALS"]
    Values = ["Amazon Elastic Compute Cloud - Compute", "Amazon Relational Database Service", "Amazon Simple Storage Service"]
  })

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-cost-anomaly-detector"
    Purpose     = "cost-anomaly-detection"
    Module      = "monitoring"
  })
}

resource "aws_ce_anomaly_subscription" "main" {
  count = var.enable_cost_anomaly_detection && var.alarm_notification_email != "" ? 1 : 0

  name      = "${local.name_prefix}-cost-anomaly-subscription"
  frequency = "DAILY"
  
  monitor_arn_list = [
    aws_ce_anomaly_detector.main[0].arn
  ]
  
  subscriber {
    type    = "EMAIL"
    address = var.alarm_notification_email
  }

  threshold_expression {
    and {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        values        = ["100"]
        match_options = ["GREATER_THAN_OR_EQUAL"]
      }
    }
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-cost-anomaly-subscription"
    Purpose     = "cost-anomaly-notifications"
    Module      = "monitoring"
  })
}