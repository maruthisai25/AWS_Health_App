
# =============================================================================
# AWS Education Platform - Global Variables
# =============================================================================

# =============================================================================
# AWS Configuration
# =============================================================================

variable "aws_account_id" {
  description = "AWS Account ID where resources will be created"
  type        = string
  
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "AWS Account ID must be a 12-digit number."
  }
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
  
  validation {
    condition = contains([
      "us-east-1", "us-east-2", "us-west-1", "us-west-2",
      "eu-west-1", "eu-west-2", "eu-central-1",
      "ap-southeast-1", "ap-southeast-2", "ap-northeast-1"
    ], var.aws_region)
    error_message = "AWS region must be a valid region."
  }
}

# =============================================================================
# Project Configuration
# =============================================================================

variable "project_name" {
  description = "Name of the project (used in resource naming)"
  type        = string
  default     = "education-platform"
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project_name))
    error_message = "Project name must start with a letter, contain only lowercase letters, numbers, and hyphens, and end with a letter or number."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "cost_center" {
  description = "Cost center for billing and tracking"
  type        = string
  default     = "engineering"
}

variable "owner" {
  description = "Owner or team responsible for the infrastructure"
  type        = string
  default     = "platform-team"
}

# =============================================================================
# Application Configuration
# =============================================================================

variable "max_chat_message_length" {
  description = "Maximum length of chat messages"
  type        = number
  default     = 1000
}

variable "session_timeout_minutes" {
  description = "User session timeout in minutes"
  type        = number
  default     = 30
}

variable "max_login_attempts" {
  description = "Maximum number of login attempts before lockout"
  type        = number
  default     = 5
}

# =============================================================================
# Development and Testing Configuration
# =============================================================================

variable "enable_debug_logging" {
  description = "Whether to enable debug logging"
  type        = bool
  default     = false
}

variable "log_level" {
  description = "Application log level"
  type        = string
  default     = "info"
  
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

variable "enable_performance_insights" {
  description = "Whether to enable RDS Performance Insights"
  type        = bool
  default     = false
}

# =============================================================================
# Additional Configuration Maps
# =============================================================================

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "subnet_tags" {
  description = "Additional tags for subnets"
  type        = map(string)
  default     = {}
}

variable "security_group_rules" {
  description = "Additional security group rules"
  type = list(object({
    type        = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = []
}
