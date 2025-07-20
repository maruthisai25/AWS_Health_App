# =============================================================================
# Attendance Module Variables
# =============================================================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "education-platform"
}

# =============================================================================
# Networking Configuration
# =============================================================================

variable "vpc_id" {
  description = "ID of the VPC where resources will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Lambda functions"
  type        = list(string)
}

# =============================================================================
# Authentication Configuration
# =============================================================================

variable "user_pool_id" {
  description = "Cognito User Pool ID for authentication"
  type        = string
}

variable "api_gateway_id" {
  description = "API Gateway ID to add attendance endpoints to"
  type        = string
  default     = ""
}

variable "api_gateway_root_resource_id" {
  description = "API Gateway root resource ID"
  type        = string
  default     = ""
}

variable "api_gateway_execution_arn" {
  description = "API Gateway execution ARN for Lambda permissions"
  type        = string
  default     = ""
}

# =============================================================================
# DynamoDB Configuration
# =============================================================================

variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PAY_PER_REQUEST or PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"
  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.dynamodb_billing_mode)
    error_message = "Billing mode must be PAY_PER_REQUEST or PROVISIONED."
  }
}

variable "dynamodb_read_capacity" {
  description = "DynamoDB read capacity units (only for PROVISIONED mode)"
  type        = number
  default     = 5
}

variable "dynamodb_write_capacity" {
  description = "DynamoDB write capacity units (only for PROVISIONED mode)"
  type        = number
  default     = 5
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB tables"
  type        = bool
  default     = false
}

variable "enable_dynamodb_encryption" {
  description = "Enable encryption at rest for DynamoDB tables"
  type        = bool
  default     = true
}

# =============================================================================
# Lambda Configuration
# =============================================================================

variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "nodejs18.x"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 256
  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrency for Lambda functions"
  type        = number
  default     = 10
}

# =============================================================================
# Attendance Configuration
# =============================================================================

variable "attendance_session_duration" {
  description = "Maximum duration for an attendance session in minutes"
  type        = number
  default     = 180  # 3 hours
}

variable "geolocation_radius_meters" {
  description = "Allowed radius from class location for attendance in meters"
  type        = number
  default     = 100
}

variable "enable_geolocation_validation" {
  description = "Enable geolocation validation for attendance"
  type        = bool
  default     = true
}

variable "qr_code_expiry_minutes" {
  description = "QR code expiry time in minutes"
  type        = number
  default     = 15
}

variable "attendance_grace_period_minutes" {
  description = "Grace period for late attendance in minutes"
  type        = number
  default     = 10
}

variable "enable_attendance_analytics" {
  description = "Enable attendance analytics and reporting"
  type        = bool
  default     = true
}

# =============================================================================
# CloudWatch Configuration
# =============================================================================

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

variable "enable_xray_tracing" {
  description = "Enable X-Ray tracing for Lambda functions"
  type        = bool
  default     = true
}

# =============================================================================
# Notification Configuration
# =============================================================================

variable "enable_attendance_notifications" {
  description = "Enable attendance notifications via SNS"
  type        = bool
  default     = true
}

variable "notification_topic_arn" {
  description = "SNS topic ARN for attendance notifications"
  type        = string
  default     = ""
}

# =============================================================================
# Reporting Configuration
# =============================================================================

variable "report_schedule_expression" {
  description = "CloudWatch Events schedule expression for attendance reports"
  type        = string
  default     = "cron(0 18 * * ? *)"  # Daily at 6 PM
}

variable "enable_csv_export" {
  description = "Enable CSV export functionality for attendance reports"
  type        = bool
  default     = true
}

variable "report_s3_bucket" {
  description = "S3 bucket for storing attendance reports"
  type        = string
  default     = ""
}

# =============================================================================
# Security Configuration
# =============================================================================

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
  default     = ""
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}