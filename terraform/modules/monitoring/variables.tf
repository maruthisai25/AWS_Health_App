# =============================================================================
# Monitoring Module Variables
# =============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 50
    error_message = "Project name must be between 1 and 50 characters."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# =============================================================================
# CloudWatch Configuration
# =============================================================================

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "dashboard_name" {
  description = "Name for the CloudWatch dashboard"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

variable "alarm_notification_email" {
  description = "Email address for alarm notifications"
  type        = string
  default     = ""
}

variable "enable_cost_monitoring" {
  description = "Enable cost monitoring and budgets"
  type        = bool
  default     = true
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 500
  validation {
    condition     = var.monthly_budget_limit > 0
    error_message = "Monthly budget limit must be greater than 0."
  }
}

# =============================================================================
# CloudTrail Configuration
# =============================================================================

variable "enable_cloudtrail" {
  description = "Enable CloudTrail logging"
  type        = bool
  default     = true
}

variable "cloudtrail_s3_bucket_name" {
  description = "S3 bucket name for CloudTrail logs (optional, will create if not provided)"
  type        = string
  default     = ""
}

variable "enable_cloudtrail_log_file_validation" {
  description = "Enable CloudTrail log file validation"
  type        = bool
  default     = true
}

variable "cloudtrail_include_global_service_events" {
  description = "Include global service events in CloudTrail"
  type        = bool
  default     = true
}

variable "cloudtrail_is_multi_region_trail" {
  description = "Make CloudTrail a multi-region trail"
  type        = bool
  default     = true
}

variable "enable_cloudtrail_data_events" {
  description = "Enable CloudTrail data events for S3 and Lambda"
  type        = bool
  default     = false
}

# =============================================================================
# X-Ray Configuration
# =============================================================================

variable "enable_xray_tracing" {
  description = "Enable X-Ray distributed tracing"
  type        = bool
  default     = true
}

variable "xray_sampling_rate" {
  description = "X-Ray sampling rate (0.0 to 1.0)"
  type        = number
  default     = 0.1
  validation {
    condition     = var.xray_sampling_rate >= 0.0 && var.xray_sampling_rate <= 1.0
    error_message = "X-Ray sampling rate must be between 0.0 and 1.0."
  }
}

# =============================================================================
# Integration Variables
# =============================================================================

variable "vpc_id" {
  description = "VPC ID for monitoring resources"
  type        = string
  default     = ""
}

variable "api_gateway_id" {
  description = "API Gateway ID for monitoring"
  type        = string
  default     = ""
}

variable "api_gateway_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "dev"
}

variable "lambda_function_names" {
  description = "List of Lambda function names to monitor"
  type        = list(string)
  default     = []
}

variable "rds_cluster_identifier" {
  description = "RDS cluster identifier for monitoring"
  type        = string
  default     = ""
}

variable "dynamodb_table_names" {
  description = "List of DynamoDB table names to monitor"
  type        = list(string)
  default     = []
}

variable "s3_bucket_names" {
  description = "List of S3 bucket names to monitor"
  type        = list(string)
  default     = []
}

variable "cloudfront_distribution_ids" {
  description = "List of CloudFront distribution IDs to monitor"
  type        = list(string)
  default     = []
}

variable "alb_arn_suffix" {
  description = "Application Load Balancer ARN suffix for monitoring"
  type        = string
  default     = ""
}

variable "opensearch_domain_name" {
  description = "OpenSearch domain name for monitoring"
  type        = string
  default     = ""
}

# =============================================================================
# Alerting Configuration
# =============================================================================

variable "enable_high_error_rate_alarms" {
  description = "Enable high error rate alarms"
  type        = bool
  default     = true
}

variable "error_rate_threshold" {
  description = "Error rate threshold percentage for alarms"
  type        = number
  default     = 5.0
  validation {
    condition     = var.error_rate_threshold > 0 && var.error_rate_threshold <= 100
    error_message = "Error rate threshold must be between 0 and 100."
  }
}

variable "enable_high_latency_alarms" {
  description = "Enable high latency alarms"
  type        = bool
  default     = true
}

variable "latency_threshold_ms" {
  description = "Latency threshold in milliseconds for alarms"
  type        = number
  default     = 5000
  validation {
    condition     = var.latency_threshold_ms > 0
    error_message = "Latency threshold must be greater than 0."
  }
}

variable "enable_cost_anomaly_detection" {
  description = "Enable cost anomaly detection"
  type        = bool
  default     = true
}

# =============================================================================
# Log Groups Configuration
# =============================================================================

variable "custom_log_groups" {
  description = "Custom log groups to create"
  type = map(object({
    retention_in_days = number
    kms_key_id       = optional(string)
  }))
  default = {}
}

variable "enable_log_insights_queries" {
  description = "Enable CloudWatch Logs Insights saved queries"
  type        = bool
  default     = true
}