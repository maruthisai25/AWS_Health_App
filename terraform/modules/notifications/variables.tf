# =============================================================================
# Notifications Module Variables
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

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Lambda functions"
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

# =============================================================================
# SES Configuration
# =============================================================================

variable "ses_domain" {
  description = "Domain for SES email sending (optional)"
  type        = string
  default     = ""
}

variable "ses_from_email" {
  description = "Default from email address"
  type        = string
  default     = "noreply@education-platform.com"
}

variable "ses_from_name" {
  description = "Default from name for emails"
  type        = string
  default     = "Education Platform"
}

variable "enable_ses_domain_verification" {
  description = "Enable SES domain verification"
  type        = bool
  default     = false
}

variable "enable_ses_dkim" {
  description = "Enable DKIM for SES domain"
  type        = bool
  default     = false
}

variable "ses_bounce_topic" {
  description = "SNS topic ARN for SES bounce notifications"
  type        = string
  default     = ""
}

variable "ses_complaint_topic" {
  description = "SNS topic ARN for SES complaint notifications"
  type        = string
  default     = ""
}

# =============================================================================
# SNS Configuration
# =============================================================================

variable "notification_topics" {
  description = "Map of notification topics to create"
  type = map(object({
    display_name = string
    description  = string
  }))
  default = {
    announcements = {
      display_name = "Announcements"
      description  = "General announcements and news"
    }
    grades = {
      display_name = "Grades"
      description  = "Grade updates and notifications"
    }
    attendance = {
      display_name = "Attendance"
      description  = "Attendance reminders and updates"
    }
    assignments = {
      display_name = "Assignments"
      description  = "Assignment notifications and deadlines"
    }
    system = {
      display_name = "System"
      description  = "System notifications and alerts"
    }
  }
}

variable "enable_sms_notifications" {
  description = "Enable SMS notifications via SNS"
  type        = bool
  default     = false
}

variable "sms_sender_id" {
  description = "Sender ID for SMS notifications"
  type        = string
  default     = "EduPlatform"
}

# =============================================================================
# Lambda Configuration
# =============================================================================

variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
  default     = "nodejs18.x"
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions in seconds"
  type        = number
  default     = 30
  validation {
    condition     = var.lambda_timeout >= 3 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 3 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda functions in MB"
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
  validation {
    condition     = var.lambda_reserved_concurrency >= 0
    error_message = "Lambda reserved concurrency must be non-negative."
  }
}

variable "enable_lambda_vpc" {
  description = "Deploy Lambda functions in VPC"
  type        = bool
  default     = true
}

variable "lambda_environment_variables" {
  description = "Environment variables for Lambda functions"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Email Templates
# =============================================================================

variable "email_templates" {
  description = "Email templates configuration"
  type = map(object({
    subject = string
    html    = string
    text    = string
  }))
  default = {
    welcome = {
      subject = "Welcome to {{platform_name}}"
      html    = "<h1>Welcome {{user_name}}!</h1><p>Thank you for joining our education platform.</p>"
      text    = "Welcome {{user_name}}! Thank you for joining our education platform."
    }
    grade_update = {
      subject = "Grade Update for {{course_name}}"
      html    = "<h2>Grade Update</h2><p>Your grade for {{assignment_name}} in {{course_name}} has been updated to {{grade}}.</p>"
      text    = "Grade Update: Your grade for {{assignment_name}} in {{course_name}} has been updated to {{grade}}."
    }
    attendance_reminder = {
      subject = "Attendance Reminder for {{class_name}}"
      html    = "<h2>Class Reminder</h2><p>Don't forget about your {{class_name}} class at {{class_time}}.</p>"
      text    = "Class Reminder: Don't forget about your {{class_name}} class at {{class_time}}."
    }
    assignment_due = {
      subject = "Assignment Due: {{assignment_name}}"
      html    = "<h2>Assignment Due Soon</h2><p>Your assignment {{assignment_name}} for {{course_name}} is due on {{due_date}}.</p>"
      text    = "Assignment Due Soon: Your assignment {{assignment_name}} for {{course_name}} is due on {{due_date}}."
    }
  }
}

# =============================================================================
# Notification Preferences
# =============================================================================

variable "default_notification_preferences" {
  description = "Default notification preferences for users"
  type = object({
    email_enabled = bool
    sms_enabled   = bool
    push_enabled  = bool
    topics = map(object({
      email = bool
      sms   = bool
      push  = bool
    }))
  })
  default = {
    email_enabled = true
    sms_enabled   = false
    push_enabled  = true
    topics = {
      announcements = { email = true, sms = false, push = true }
      grades        = { email = true, sms = false, push = true }
      attendance    = { email = true, sms = false, push = true }
      assignments   = { email = true, sms = false, push = true }
      system        = { email = true, sms = false, push = false }
    }
  }
}

# =============================================================================
# CloudWatch Configuration
# =============================================================================

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
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

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = false
}

# =============================================================================
# Security Configuration
# =============================================================================

variable "allowed_sender_emails" {
  description = "List of allowed sender email addresses"
  type        = list(string)
  default     = []
}

variable "rate_limit_per_minute" {
  description = "Rate limit for notifications per minute per user"
  type        = number
  default     = 10
  validation {
    condition     = var.rate_limit_per_minute > 0 && var.rate_limit_per_minute <= 1000
    error_message = "Rate limit must be between 1 and 1000 per minute."
  }
}

variable "enable_notification_encryption" {
  description = "Enable encryption for notification data"
  type        = bool
  default     = true
}

# =============================================================================
# Integration Configuration
# =============================================================================

variable "user_pool_id" {
  description = "Cognito User Pool ID for user information"
  type        = string
  default     = ""
}

variable "api_gateway_id" {
  description = "API Gateway ID for notification endpoints"
  type        = string
  default     = ""
}

variable "dynamodb_table_arns" {
  description = "Map of DynamoDB table ARNs for notification preferences"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Cost Optimization
# =============================================================================

variable "enable_cost_optimization" {
  description = "Enable cost optimization features"
  type        = bool
  default     = true
}

variable "notification_batch_size" {
  description = "Batch size for processing notifications"
  type        = number
  default     = 10
  validation {
    condition     = var.notification_batch_size >= 1 && var.notification_batch_size <= 100
    error_message = "Notification batch size must be between 1 and 100."
  }
}

variable "enable_dead_letter_queue" {
  description = "Enable dead letter queue for failed notifications"
  type        = bool
  default     = true
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "sns_tags" {
  description = "Additional tags for SNS resources"
  type        = map(string)
  default     = {}
}

variable "ses_tags" {
  description = "Additional tags for SES resources"
  type        = map(string)
  default     = {}
}

variable "lambda_tags" {
  description = "Additional tags for Lambda resources"
  type        = map(string)
  default     = {}
}