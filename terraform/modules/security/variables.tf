# =============================================================================
# Security Module Variables
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

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "api_gateway_id" {
  description = "ID of the API Gateway"
  type        = string
  default     = ""
}

variable "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  type        = string
  default     = ""
}

variable "alb_arn" {
  description = "ARN of the Application Load Balancer"
  type        = string
  default     = ""
}

# =============================================================================
# WAF Configuration
# =============================================================================

variable "enable_waf" {
  description = "Enable AWS WAF protection"
  type        = bool
  default     = true
}

variable "waf_scope" {
  description = "Scope for WAF (REGIONAL or CLOUDFRONT)"
  type        = string
  default     = "REGIONAL"
  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.waf_scope)
    error_message = "WAF scope must be either REGIONAL or CLOUDFRONT."
  }
}

variable "waf_rules" {
  description = "WAF rules configuration"
  type = object({
    enable_rate_limiting     = bool
    enable_geo_blocking      = bool
    enable_ip_reputation     = bool
    enable_known_bad_inputs  = bool
    enable_sql_injection     = bool
    enable_xss_protection    = bool
    enable_size_restrictions = bool
  })
  default = {
    enable_rate_limiting     = true
    enable_geo_blocking      = false
    enable_ip_reputation     = true
    enable_known_bad_inputs  = true
    enable_sql_injection     = true
    enable_xss_protection    = true
    enable_size_restrictions = true
  }
}

variable "rate_limit_requests" {
  description = "Rate limit requests per 5-minute window"
  type        = number
  default     = 2000
  validation {
    condition     = var.rate_limit_requests >= 100 && var.rate_limit_requests <= 20000000
    error_message = "Rate limit must be between 100 and 20,000,000 requests."
  }
}

variable "blocked_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for country in var.blocked_countries : can(regex("^[A-Z]{2}$", country))
    ])
    error_message = "Country codes must be valid ISO 3166-1 alpha-2 codes (e.g., 'CN', 'RU')."
  }
}

variable "allowed_countries" {
  description = "List of country codes to allow (empty means allow all except blocked)"
  type        = list(string)
  default     = []
}

variable "ip_whitelist" {
  description = "List of IP addresses/CIDR blocks to whitelist"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for ip in var.ip_whitelist : can(cidrhost(ip, 0))
    ])
    error_message = "All IP addresses must be valid CIDR notation."
  }
}

variable "ip_blacklist" {
  description = "List of IP addresses/CIDR blocks to blacklist"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for ip in var.ip_blacklist : can(cidrhost(ip, 0))
    ])
    error_message = "All IP addresses must be valid CIDR notation."
  }
}

# =============================================================================
# IAM Configuration
# =============================================================================

variable "enable_iam_access_analyzer" {
  description = "Enable IAM Access Analyzer"
  type        = bool
  default     = true
}

variable "enable_password_policy" {
  description = "Enable IAM password policy"
  type        = bool
  default     = true
}

variable "password_policy" {
  description = "IAM password policy configuration"
  type = object({
    minimum_password_length        = number
    require_lowercase_characters   = bool
    require_uppercase_characters   = bool
    require_numbers               = bool
    require_symbols               = bool
    allow_users_to_change_password = bool
    max_password_age              = number
    password_reuse_prevention     = number
  })
  default = {
    minimum_password_length        = 12
    require_lowercase_characters   = true
    require_uppercase_characters   = true
    require_numbers               = true
    require_symbols               = true
    allow_users_to_change_password = true
    max_password_age              = 90
    password_reuse_prevention     = 12
  }
}

variable "create_security_roles" {
  description = "Create additional security-focused IAM roles"
  type        = bool
  default     = true
}

# =============================================================================
# KMS Configuration
# =============================================================================

variable "kms_key_rotation_enabled" {
  description = "Enable automatic KMS key rotation"
  type        = bool
  default     = true
}

variable "kms_key_deletion_window" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 30
  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days."
  }
}

variable "create_additional_kms_keys" {
  description = "Create additional KMS keys for different services"
  type        = bool
  default     = true
}

# =============================================================================
# GuardDuty Configuration
# =============================================================================

variable "enable_guardduty" {
  description = "Enable AWS GuardDuty"
  type        = bool
  default     = true
}

variable "guardduty_finding_publishing_frequency" {
  description = "GuardDuty finding publishing frequency"
  type        = string
  default     = "SIX_HOURS"
  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.guardduty_finding_publishing_frequency)
    error_message = "GuardDuty frequency must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

variable "enable_guardduty_s3_protection" {
  description = "Enable GuardDuty S3 protection"
  type        = bool
  default     = true
}

variable "enable_guardduty_malware_protection" {
  description = "Enable GuardDuty malware protection"
  type        = bool
  default     = false  # Additional cost
}

# =============================================================================
# Security Hub Configuration
# =============================================================================

variable "enable_security_hub" {
  description = "Enable AWS Security Hub"
  type        = bool
  default     = true
}

variable "security_hub_standards" {
  description = "Security Hub standards to enable"
  type        = list(string)
  default     = ["aws-foundational-security-standard", "cis-aws-foundations-benchmark"]
  validation {
    condition = alltrue([
      for standard in var.security_hub_standards : contains([
        "aws-foundational-security-standard",
        "cis-aws-foundations-benchmark",
        "pci-dss"
      ], standard)
    ])
    error_message = "Invalid Security Hub standard specified."
  }
}

# =============================================================================
# Config Configuration
# =============================================================================

variable "enable_config" {
  description = "Enable AWS Config"
  type        = bool
  default     = true
}

variable "config_delivery_frequency" {
  description = "Config delivery frequency"
  type        = string
  default     = "TwentyFour_Hours"
  validation {
    condition = contains([
      "One_Hour", "Three_Hours", "Six_Hours", "Twelve_Hours", "TwentyFour_Hours"
    ], var.config_delivery_frequency)
    error_message = "Invalid Config delivery frequency."
  }
}

# =============================================================================
# CloudTrail Configuration
# =============================================================================

variable "enable_cloudtrail" {
  description = "Enable AWS CloudTrail"
  type        = bool
  default     = true
}

variable "cloudtrail_include_global_service_events" {
  description = "Include global service events in CloudTrail"
  type        = bool
  default     = true
}

variable "cloudtrail_is_multi_region_trail" {
  description = "Make CloudTrail multi-region"
  type        = bool
  default     = true
}

variable "cloudtrail_enable_log_file_validation" {
  description = "Enable CloudTrail log file validation"
  type        = bool
  default     = true
}

variable "cloudtrail_s3_key_prefix" {
  description = "S3 key prefix for CloudTrail logs"
  type        = string
  default     = "cloudtrail-logs"
}

# =============================================================================
# VPC Security Configuration
# =============================================================================

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "vpc_flow_logs_retention" {
  description = "VPC Flow Logs retention in days"
  type        = number
  default     = 30
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.vpc_flow_logs_retention)
    error_message = "VPC Flow Logs retention must be a valid CloudWatch retention period."
  }
}

variable "enable_network_acls" {
  description = "Enable additional Network ACLs"
  type        = bool
  default     = true
}

# =============================================================================
# Secrets Manager Configuration
# =============================================================================

variable "enable_secrets_manager" {
  description = "Enable AWS Secrets Manager for sensitive data"
  type        = bool
  default     = true
}

variable "secrets_recovery_window" {
  description = "Recovery window for deleted secrets in days"
  type        = number
  default     = 30
  validation {
    condition     = var.secrets_recovery_window >= 7 && var.secrets_recovery_window <= 30
    error_message = "Secrets recovery window must be between 7 and 30 days."
  }
}

# =============================================================================
# Monitoring and Alerting
# =============================================================================

variable "enable_security_monitoring" {
  description = "Enable security monitoring and alerting"
  type        = bool
  default     = true
}

variable "security_notification_email" {
  description = "Email address for security notifications"
  type        = string
  default     = ""
}

variable "enable_cost_anomaly_detection" {
  description = "Enable AWS Cost Anomaly Detection"
  type        = bool
  default     = true
}

# =============================================================================
# Compliance Configuration
# =============================================================================

variable "compliance_framework" {
  description = "Compliance framework to follow"
  type        = string
  default     = "general"
  validation {
    condition     = contains(["general", "hipaa", "pci-dss", "sox", "gdpr"], var.compliance_framework)
    error_message = "Compliance framework must be one of: general, hipaa, pci-dss, sox, gdpr."
  }
}

variable "enable_encryption_at_rest" {
  description = "Enforce encryption at rest for all services"
  type        = bool
  default     = true
}

variable "enable_encryption_in_transit" {
  description = "Enforce encryption in transit for all services"
  type        = bool
  default     = true
}

# =============================================================================
# Cost Optimization
# =============================================================================

variable "enable_cost_optimization" {
  description = "Enable cost optimization features"
  type        = bool
  default     = true
}

variable "security_budget_limit" {
  description = "Monthly budget limit for security services in USD"
  type        = number
  default     = 100
  validation {
    condition     = var.security_budget_limit >= 10 && var.security_budget_limit <= 10000
    error_message = "Security budget limit must be between $10 and $10,000."
  }
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "security_tags" {
  description = "Additional tags for security resources"
  type        = map(string)
  default     = {}
}