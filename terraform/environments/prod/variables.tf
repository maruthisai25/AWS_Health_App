# =============================================================================
# AWS Education Platform - Development Environment Variables
# =============================================================================
#
# This file defines variables specific to the development environment.
# These variables can be overridden in terraform.tfvars or via command line.
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
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "cost_center" {
  description = "Cost center for billing purposes"
  type        = string
  default     = "education-dev"
}

variable "owner" {
  description = "Owner or team responsible for the infrastructure"
  type        = string
  default     = "platform-team"
}

# =============================================================================
# Networking Configuration
# =============================================================================

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

# =============================================================================
# Database Configuration
# =============================================================================

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "education_platform_dev"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "Database name must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "db_username" {
  description = "Username for the database"
  type        = string
  default     = "eduadmin"
  sensitive   = true
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_username))
    error_message = "Database username must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "db_password" {
  description = "Password for the database"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Database password must be at least 8 characters long."
  }
}

# =============================================================================
# Development-Specific Configuration
# =============================================================================

variable "enable_detailed_monitoring" {
  description = "Whether to enable detailed CloudWatch monitoring"
  type        = bool
  default     = false
}

variable "enable_debug_logging" {
  description = "Whether to enable debug logging"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain logs in CloudWatch"
  type        = number
  default     = 7
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch log retention value."
  }
}

# =============================================================================
# Security Configuration
# =============================================================================

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access development resources"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Wide open for dev - restrict in production
  
  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid IPv4 CIDR notation."
  }
}

variable "enable_bastion_host" {
  description = "Whether to create a bastion host for secure access"
  type        = bool
  default     = false  # Disabled by default for dev cost savings
}

# =============================================================================
# Feature Flags for Development
# =============================================================================

variable "enable_chat" {
  description = "Whether to enable the chat functionality"
  type        = bool
  default     = true
}

variable "enable_video" {
  description = "Whether to enable video lecture functionality"
  type        = bool
  default     = true
}

variable "enable_attendance" {
  description = "Whether to enable attendance tracking"
  type        = bool
  default     = true
}

variable "enable_marks" {
  description = "Whether to enable marks/grades management"
  type        = bool
  default     = true
}

variable "enable_notifications" {
  description = "Whether to enable notification system"
  type        = bool
  default     = false  # Disabled by default for dev
}

variable "enable_security" {
  description = "Whether to enable security module"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Whether to enable monitoring module"
  type        = bool
  default     = true
}

# =============================================================================
# Cost Optimization Settings
# =============================================================================

variable "cost_optimization_enabled" {
  description = "Whether to enable cost optimization features for development"
  type        = bool
  default     = true
}

variable "auto_stop_instances" {
  description = "Whether to automatically stop instances during non-working hours"
  type        = bool
  default     = false  # Can be enabled for further cost savings
}

variable "use_spot_instances" {
  description = "Whether to use spot instances where possible"
  type        = bool
  default     = false  # Can be enabled for cost savings
}

# =============================================================================
# Backup and Recovery Configuration
# =============================================================================

variable "backup_retention_days" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 1  # Minimal retention for dev
  
  validation {
    condition     = var.backup_retention_days >= 0 && var.backup_retention_days <= 35
    error_message = "Backup retention days must be between 0 and 35."
  }
}

variable "enable_deletion_protection" {
  description = "Whether to enable deletion protection on critical resources"
  type        = bool
  default     = false  # Disabled for dev to allow easy cleanup
}

# =============================================================================
# Development Tools Configuration
# =============================================================================

variable "enable_development_tools" {
  description = "Whether to enable development and debugging tools"
  type        = bool
  default     = true
}

variable "create_development_user" {
  description = "Whether to create a development IAM user with broad permissions"
  type        = bool
  default     = false
}

# =============================================================================
# Testing Configuration
# =============================================================================

variable "enable_test_data" {
  description = "Whether to create test data and sample users"
  type        = bool
  default     = true
}

variable "test_user_count" {
  description = "Number of test users to create"
  type        = number
  default     = 10
  
  validation {
    condition     = var.test_user_count >= 0 && var.test_user_count <= 100
    error_message = "Test user count must be between 0 and 100."
  }
}

# =============================================================================
# Performance Configuration
# =============================================================================

variable "performance_mode" {
  description = "Performance mode for development (standard or high_performance)"
  type        = string
  default     = "standard"
  
  validation {
    condition     = contains(["standard", "high_performance"], var.performance_mode)
    error_message = "Performance mode must be either 'standard' or 'high_performance'."
  }
}

# =============================================================================
# Additional Tags
# =============================================================================

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "development"
    Purpose     = "education-platform-dev"
    AutoStop    = "true"  # Tag for automated cost management
  }
}
