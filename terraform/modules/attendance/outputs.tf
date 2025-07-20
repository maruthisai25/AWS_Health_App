# =============================================================================
# Attendance Module Outputs
# =============================================================================

# DynamoDB Table Outputs
output "attendance_table_name" {
  description = "Name of the attendance DynamoDB table"
  value       = aws_dynamodb_table.attendance.name
}

output "attendance_table_arn" {
  description = "ARN of the attendance DynamoDB table"
  value       = aws_dynamodb_table.attendance.arn
}

output "classes_table_name" {
  description = "Name of the classes DynamoDB table"
  value       = aws_dynamodb_table.classes.name
}

output "classes_table_arn" {
  description = "ARN of the classes DynamoDB table"
  value       = aws_dynamodb_table.classes.arn
}

# Lambda Function Outputs
output "attendance_tracker_function_name" {
  description = "Name of the attendance tracker Lambda function"
  value       = aws_lambda_function.attendance_tracker.function_name
}

output "attendance_tracker_function_arn" {
  description = "ARN of the attendance tracker Lambda function"
  value       = aws_lambda_function.attendance_tracker.arn
}

output "attendance_reporter_function_name" {
  description = "Name of the attendance reporter Lambda function"
  value       = aws_lambda_function.attendance_reporter.function_name
}

output "attendance_reporter_function_arn" {
  description = "ARN of the attendance reporter Lambda function"
  value       = aws_lambda_function.attendance_reporter.arn
}

# API Gateway Outputs
output "api_gateway_attendance_resource_id" {
  description = "ID of the attendance API Gateway resource"
  value       = try(aws_api_gateway_resource.attendance[0].id, null)
}

output "attendance_api_endpoints" {
  description = "Attendance API endpoints"
  value = var.api_gateway_id != "" ? {
    check_in     = "POST /attendance/check-in"
    check_out    = "POST /attendance/check-out"
    status       = "GET /attendance/status/{userId}"
    history      = "GET /attendance/history/{userId}"
    class_qr     = "POST /attendance/class/{classId}/qr"
    reports      = "GET /attendance/reports"
    analytics    = "GET /attendance/analytics"
  } : {}
}

# CloudWatch Outputs
output "attendance_log_groups" {
  description = "CloudWatch log group names for attendance functions"
  value = {
    tracker  = aws_cloudwatch_log_group.attendance_tracker.name
    reporter = aws_cloudwatch_log_group.attendance_reporter.name
  }
}

# IAM Role Outputs
output "attendance_lambda_role_arn" {
  description = "ARN of the attendance Lambda execution role"
  value       = aws_iam_role.attendance_lambda.arn
}

# EventBridge Rule Output
output "attendance_report_rule_arn" {
  description = "ARN of the attendance report EventBridge rule"
  value       = aws_cloudwatch_event_rule.attendance_report.arn
}

# Security Group Output
output "attendance_lambda_security_group_id" {
  description = "ID of the attendance Lambda security group"
  value       = aws_security_group.attendance_lambda.id
}

# Configuration Outputs
output "attendance_configuration" {
  description = "Attendance system configuration"
  value = {
    session_duration_minutes     = var.attendance_session_duration
    geolocation_radius_meters   = var.geolocation_radius_meters
    qr_code_expiry_minutes      = var.qr_code_expiry_minutes
    grace_period_minutes        = var.attendance_grace_period_minutes
    geolocation_enabled         = var.enable_geolocation_validation
    analytics_enabled           = var.enable_attendance_analytics
    notifications_enabled       = var.enable_attendance_notifications
  }
}