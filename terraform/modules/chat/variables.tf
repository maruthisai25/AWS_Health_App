# Chat Module Variables

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "education-platform"
}

variable "vpc_id" {
  description = "VPC ID for Lambda functions"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda functions"
  type        = list(string)
}

variable "user_pool_id" {
  description = "Cognito User Pool ID for authentication"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# DynamoDB Configuration
variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "dynamodb_read_capacity" {
  description = "DynamoDB read capacity units (used when billing_mode is PROVISIONED)"
  type        = number
  default     = 5
}

variable "dynamodb_write_capacity" {
  description = "DynamoDB write capacity units (used when billing_mode is PROVISIONED)"
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

# OpenSearch Configuration
variable "enable_opensearch" {
  description = "Enable OpenSearch for message search functionality"
  type        = bool
  default     = true
}

variable "opensearch_instance_type" {
  description = "OpenSearch instance type"
  type        = string
  default     = "t3.small.search"
}

variable "opensearch_instance_count" {
  description = "Number of OpenSearch instances"
  type        = number
  default     = 1
}

variable "opensearch_ebs_volume_size" {
  description = "OpenSearch EBS volume size in GB"
  type        = number
  default     = 20
}

variable "opensearch_version" {
  description = "OpenSearch version"
  type        = string
  default     = "OpenSearch_2.3"
}

# AppSync Configuration
variable "appsync_authentication_type" {
  description = "Primary authentication type for AppSync API"
  type        = string
  default     = "AWS_LAMBDA"
}

variable "appsync_log_level" {
  description = "CloudWatch log level for AppSync API"
  type        = string
  default     = "ERROR"
}

variable "enable_appsync_field_logs" {
  description = "Enable field-level logging for AppSync"
  type        = bool
  default     = false
}

variable "appsync_xray_enabled" {
  description = "Enable X-Ray tracing for AppSync"
  type        = bool
  default     = true
}

# Lambda Configuration
variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "nodejs18.x"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 256
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrency for Lambda functions"
  type        = number
  default     = 10
}

# CloudWatch Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

# Chat Configuration
variable "max_message_length" {
  description = "Maximum length of chat messages"
  type        = number
  default     = 1000
}

variable "max_room_members" {
  description = "Maximum number of members per chat room"
  type        = number
  default     = 100
}

variable "message_history_days" {
  description = "Number of days to keep message history"
  type        = number
  default     = 90
}

variable "typing_indicator_timeout" {
  description = "Typing indicator timeout in seconds"
  type        = number
  default     = 10
}

variable "presence_timeout" {
  description = "User presence timeout in seconds"
  type        = number
  default     = 300
}

# CORS Configuration
variable "cors_allowed_origins" {
  description = "Allowed origins for CORS (for development)"
  type        = list(string)
  default     = ["*"]
}

# Additional Configuration Variables
variable "enable_cost_optimization" {
  description = "Enable cost optimization features"
  type        = bool
  default     = false
}

variable "opensearch_dedicated_master_enabled" {
  description = "Whether to enable dedicated master nodes for OpenSearch"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
  default     = ""
}

variable "cloudwatch_log_retention" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring for resources"
  type        = bool
  default     = false
}

variable "message_retention_days" {
  description = "Number of days to retain messages"
  type        = number
  default     = 30
}

variable "enable_opensearch_slow_logs" {
  description = "Enable OpenSearch slow logs"
  type        = bool
  default     = false
}
