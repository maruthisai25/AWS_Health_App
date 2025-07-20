# =============================================================================
# Monitoring Module Outputs
# =============================================================================

# CloudWatch Dashboard
output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = var.enable_detailed_monitoring ? "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main[0].dashboard_name}" : ""
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = var.enable_detailed_monitoring ? aws_cloudwatch_dashboard.main[0].dashboard_name : ""
}

# SNS Topics
output "alarm_topic_arn" {
  description = "ARN of the SNS topic for alarms"
  value       = aws_sns_topic.alarms.arn
}

output "cost_alert_topic_arn" {
  description = "ARN of the SNS topic for cost alerts"
  value       = var.enable_cost_monitoring ? aws_sns_topic.cost_alerts[0].arn : ""
}

# CloudTrail
output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].arn : ""
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket name for CloudTrail logs"
  value       = var.enable_cloudtrail ? local.cloudtrail_bucket_name : ""
}

# X-Ray
output "xray_encryption_config" {
  description = "X-Ray encryption configuration"
  value       = var.enable_xray_tracing ? aws_xray_encryption_config.main[0] : null
}

# Log Groups
output "log_group_names" {
  description = "Names of created log groups"
  value = merge(
    { for k, v in aws_cloudwatch_log_group.custom : k => v.name },
    {
      application = aws_cloudwatch_log_group.application.name
      security    = aws_cloudwatch_log_group.security.name
      performance = aws_cloudwatch_log_group.performance.name
    }
  )
}

output "log_group_arns" {
  description = "ARNs of created log groups"
  value = merge(
    { for k, v in aws_cloudwatch_log_group.custom : k => v.arn },
    {
      application = aws_cloudwatch_log_group.application.arn
      security    = aws_cloudwatch_log_group.security.arn
      performance = aws_cloudwatch_log_group.performance.arn
    }
  )
}

# Alarms
output "alarm_names" {
  description = "Names of created CloudWatch alarms"
  value = merge(
    { for k, v in aws_cloudwatch_metric_alarm.lambda_errors : k => v.alarm_name },
    { for k, v in aws_cloudwatch_metric_alarm.lambda_duration : k => v.alarm_name },
    { for k, v in aws_cloudwatch_metric_alarm.api_gateway_errors : k => v.alarm_name },
    { for k, v in aws_cloudwatch_metric_alarm.api_gateway_latency : k => v.alarm_name },
    { for k, v in aws_cloudwatch_metric_alarm.dynamodb_throttles : k => v.alarm_name },
    { for k, v in aws_cloudwatch_metric_alarm.rds_cpu : k => v.alarm_name },
    { for k, v in aws_cloudwatch_metric_alarm.alb_response_time : k => v.alarm_name }
  )
}

# Budget
output "budget_name" {
  description = "Name of the cost budget"
  value       = var.enable_cost_monitoring ? aws_budgets_budget.monthly[0].name : ""
}

# Cost Anomaly Detection
output "cost_anomaly_detector_arn" {
  description = "ARN of the cost anomaly detector"
  value       = var.enable_cost_anomaly_detection ? aws_ce_anomaly_detector.main[0].arn : ""
}

# Saved Queries
output "log_insights_query_names" {
  description = "Names of CloudWatch Logs Insights saved queries"
  value       = var.enable_log_insights_queries ? [for q in aws_logs_query_definition.saved_queries : q.name] : []
}

# Monitoring Configuration Summary
output "monitoring_summary" {
  description = "Summary of monitoring configuration"
  value = {
    environment                = var.environment
    detailed_monitoring_enabled = var.enable_detailed_monitoring
    cloudtrail_enabled         = var.enable_cloudtrail
    xray_tracing_enabled       = var.enable_xray_tracing
    cost_monitoring_enabled    = var.enable_cost_monitoring
    monthly_budget_limit       = var.monthly_budget_limit
    log_retention_days         = var.log_retention_days
    alarm_notification_email   = var.alarm_notification_email != "" ? "configured" : "not_configured"
    total_alarms_created = length(aws_cloudwatch_metric_alarm.lambda_errors) + length(aws_cloudwatch_metric_alarm.lambda_duration) + length(aws_cloudwatch_metric_alarm.api_gateway_errors) + length(aws_cloudwatch_metric_alarm.api_gateway_latency) + length(aws_cloudwatch_metric_alarm.dynamodb_throttles) + length(aws_cloudwatch_metric_alarm.rds_cpu) + length(aws_cloudwatch_metric_alarm.alb_response_time)
  }
}

