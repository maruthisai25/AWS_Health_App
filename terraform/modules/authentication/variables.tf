# =============================================================================
# AWS Education Platform - Authentication Module Variables
# =============================================================================

variable "name_prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs for Lambda functions"
  type        = list(string)
}

variable "domain_name" {
  description = "Domain name for API Gateway custom domain"
  type        = string
  default     = ""
}

variable "enable_mfa" {
  description = "Enable MFA for user pool"
  type        = bool
  default     = false
}

variable "password_minimum_length" {
  description = "Minimum password length"
  type        = number
  default     = 8
}

variable "password_require_lowercase" {
  description = "Require lowercase letters in password"
  type        = bool
  default     = true
}

variable "password_require_uppercase" {
  description = "Require uppercase letters in password"
  type        = bool
  default     = true
}

variable "password_require_numbers" {
  description = "Require numbers in password"
  type        = bool
  default     = true
}

variable "password_require_symbols" {
  description = "Require symbols in password"
  type        = bool
  default     = true
}

variable "cognito_lambda_config" {
  description = "Configuration for Cognito Lambda triggers"
  type = object({
    pre_signup         = bool
    post_confirmation  = bool
    pre_authentication = bool
    post_authentication = bool
  })
  default = {
    pre_signup         = true
    post_confirmation  = true
    pre_authentication = false
    post_authentication = false
  }
}

variable "api_gateway_config" {
  description = "API Gateway configuration"
  type = object({
    throttle_burst_limit = number
    throttle_rate_limit  = number
    enable_cors         = bool
    cors_allow_origins  = list(string)
    cors_allow_methods  = list(string)
    cors_allow_headers  = list(string)
  })
  default = {
    throttle_burst_limit = 1000
    throttle_rate_limit  = 500
    enable_cors         = true
    cors_allow_origins  = ["*"]
    cors_allow_methods  = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    cors_allow_headers  = ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"]
  }
}

variable "email_config" {
  description = "Email configuration for Cognito"
  type = object({
    from_email_address = string
    reply_to_email     = string
    source_arn         = string
  })
  default = {
    from_email_address = ""
    reply_to_email     = ""
    source_arn         = ""
  }
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption"
  type        = string
}

variable "cloudwatch_log_retention" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
