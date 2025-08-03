# =============================================================================
# AWS Education Platform - Development Environment
# =============================================================================
#
# This file defines the development environment infrastructure including:
# - Networking (VPC, subnets, security groups)
# - Authentication (Cognito, API Gateway)
# - Basic resources (KMS, CloudWatch, Parameter Store)
#
# Usage:
# 1. Update terraform.tfvars with your AWS Account ID
# 2. Run: terraform init -backend-config=backend.hcl
# 3. Run: terraform plan
# 4. Run: terraform apply
# =============================================================================

# =============================================================================
# Data Sources
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# Local Values
# =============================================================================

locals {
  environment = "dev"
  name_prefix = "${var.project_name}-${local.environment}"

  # Development-specific configuration
  dev_config = {
    instance_types = {
      web_tier = "t3.micro"
      app_tier = "t3.small"
      db_tier  = "db.t3.micro"
    }
    scaling_config = {
      min_capacity     = 1
      max_capacity     = 3
      desired_capacity = 1
    }
    log_retention_days = 7
    backup_retention   = 1
  }

  # Common tags for all resources
  common_tags = merge(var.additional_tags, {
    Environment = local.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    CostCenter  = var.cost_center
    Owner       = var.owner
  })
}

# =============================================================================
# Networking Module
# =============================================================================

module "networking" {
  source = "../../modules/networking"

  # Basic configuration
  name_prefix    = local.name_prefix
  environment    = local.environment
  project_name   = var.project_name
  
  # Networking configuration
  vpc_cidr                = var.vpc_cidr
  availability_zones_count = 2  # Use 2 AZs for dev to reduce costs
  single_nat_gateway      = true  # Single NAT for dev cost optimization
  
  # Development-specific settings
  enable_flow_logs         = true
  flow_logs_retention_days = local.dev_config.log_retention_days
  
  # Tags
  common_tags = local.common_tags
}

# =============================================================================
# Authentication Module
# =============================================================================

module "authentication" {
  source = "../../modules/authentication"

  # Basic configuration
  name_prefix  = local.name_prefix
  environment  = local.environment
  project_name = var.project_name

  # Networking
  vpc_id          = module.networking.vpc_id
  private_subnets = module.networking.private_subnets

  # Domain configuration (optional)
  domain_name = ""  # Set this to your domain name if you have one

  # Security settings
  enable_mfa                 = false  # Disable MFA for development
  password_minimum_length    = 8
  password_require_lowercase = true
  password_require_uppercase = true
  password_require_numbers   = true
  password_require_symbols   = false  # Relax for development

  # Lambda configuration
  cognito_lambda_config = {
    pre_signup         = true
    post_confirmation  = true
    pre_authentication = false
    post_authentication = false
  }

  # API Gateway configuration
  api_gateway_config = {
    throttle_burst_limit = 500   # Lower for dev
    throttle_rate_limit  = 100   # Lower for dev
    enable_cors         = true
    cors_allow_origins  = ["*"]  # Allow all origins for dev
    cors_allow_methods  = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    cors_allow_headers  = ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"]
  }

  # Encryption
  kms_key_arn = aws_kms_key.main.arn

  # Logging
  cloudwatch_log_retention = local.dev_config.log_retention_days

  # Tags
  common_tags = local.common_tags

  depends_on = [
    module.networking,
    aws_kms_key.main
  ]
}

# =============================================================================
# Static Hosting Module
# =============================================================================

module "static_hosting" {
  source = "../../modules/static-hosting"

  # Basic configuration
  project_name = var.project_name
  environment  = local.environment

  # Domain configuration (optional for dev)
  enable_custom_domain  = false  # Set to true if you have a domain
  domain_name          = ""      # Your domain name
  subdomain           = "app"    # Subdomain for the app

  # CloudFront configuration
  cloudfront_price_class = "PriceClass_100"  # Cost-optimized for dev
  cloudfront_default_ttl = 86400             # 1 day
  cloudfront_max_ttl     = 31536000          # 1 year

  # S3 configuration
  s3_force_destroy        = true   # Allow destroy for dev environment
  s3_versioning_enabled   = true
  s3_lifecycle_enabled    = true
  cors_allowed_origins    = ["*"]  # Allow all origins for dev

  # Logging
  enable_cloudfront_logging = true

  # Tags
  tags = local.common_tags
}

# =============================================================================
# Chat Module
# =============================================================================

module "chat" {
  count  = var.enable_chat ? 1 : 0
  source = "../../modules/chat"

  # Basic configuration
  project_name = var.project_name
  environment  = local.environment

  # Networking
  vpc_id          = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids

  # Authentication integration
  user_pool_id = module.authentication.user_pool_id

  # Database configuration
  dynamodb_billing_mode = "PAY_PER_REQUEST"  # Cost-optimized for dev
  
  # Cost optimization for development
  enable_cost_optimization = true
  opensearch_instance_type = "t3.small.search"  # Smaller instance for dev
  opensearch_instance_count = 1
  opensearch_dedicated_master_enabled = false
  
  # Security
  kms_key_arn = aws_kms_key.main.arn
  
  # Monitoring
  cloudwatch_log_retention = local.dev_config.log_retention_days
  enable_detailed_monitoring = false  # Disabled for dev cost savings
  
  # Development settings
  max_message_length = 1000
  max_room_members = 100
  message_retention_days = 30  # Shorter retention for dev
  
  # OpenSearch configuration
  opensearch_ebs_volume_size = 20  # Smaller volume for dev
  enable_opensearch_slow_logs = false
  
  # Lambda configuration
  lambda_memory_size = 512
  lambda_timeout = 300
  lambda_runtime = "nodejs18.x"
  
  # Tags
  tags = local.common_tags

  depends_on = [
    module.networking,
    aws_kms_key.main
  ]
}

# =============================================================================
# Video Module
# =============================================================================

module "video" {
  count  = var.enable_video ? 1 : 0
  source = "../../modules/video"

  # Basic configuration
  name_prefix  = local.name_prefix
  environment  = local.environment
  project_name = var.project_name

  # Networking
  vpc_id          = module.networking.vpc_id
  private_subnets = module.networking.private_subnets

  # Video processing configuration
  enable_transcoding_presets = {
    enable_1080p = true
    enable_720p  = true
    enable_480p  = true
    enable_hls   = true
  }
  
  # Storage configuration
  enable_video_versioning = true
  video_lifecycle_enabled = true
  raw_video_retention_days = 30       # Keep raw videos for 30 days
  transcoded_video_retention_days = 90 # Keep transcoded videos for 90 days

  # CDN configuration
  enable_video_cdn = true
  cloudfront_price_class = "PriceClass_100"  # Cost-optimized for dev
  enable_signed_urls = false  # Disable for dev, enable for production

  # Lambda configuration
  lambda_runtime = "nodejs18.x"
  lambda_memory_size = 512
  lambda_timeout = 300
  enable_lambda_vpc = true

  # Security
  kms_key_arn = aws_kms_key.main.arn
  enable_bucket_encryption = true
  max_video_size_mb = 2000  # 2GB max for dev
  allowed_upload_origins = ["*"]  # Allow all origins for dev

  # Cost optimization for development
  enable_cost_optimization = false
  enable_transfer_acceleration = false
  
  # Monitoring
  enable_cloudwatch_metrics = true
  cloudwatch_log_retention = local.dev_config.log_retention_days
  enable_video_analytics = true

  # Advanced features (disabled for dev)
  enable_video_search = false
  enable_video_captions = false
  enable_content_moderation = false
  enable_video_watermarking = false
  
  # Performance settings
  enable_multipart_upload = true
  multipart_threshold_mb = 100
  concurrent_upload_parts = 3

  # Tags
  common_tags = local.common_tags
  video_bucket_tags = {
    ContentType = "video"
    Module = "video-lecture-system"
  }
  lambda_tags = {
    Runtime = "nodejs18.x"
    Module = "video-processing"
  }
  cloudfront_tags = {
    Service = "video-cdn"
    Module = "video-streaming"
  }

  depends_on = [
    module.networking,
    aws_kms_key.main
  ]
}

# =============================================================================
# Attendance Module
# =============================================================================

module "attendance" {
  count  = var.enable_attendance ? 1 : 0
  source = "../../modules/attendance"

  # Basic configuration
  environment  = local.environment
  project_name = var.project_name

  # Networking
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids

  # Authentication
  user_pool_id                   = module.authentication.user_pool_id
  api_gateway_id                 = module.authentication.api_gateway_id
  api_gateway_root_resource_id   = module.authentication.api_gateway_root_resource_id
  api_gateway_execution_arn      = module.authentication.api_gateway_execution_arn

  # DynamoDB configuration
  dynamodb_billing_mode          = "PAY_PER_REQUEST"
  enable_point_in_time_recovery  = false
  enable_dynamodb_encryption     = true

  # Lambda configuration
  lambda_runtime                 = "nodejs18.x"
  lambda_timeout                 = 30
  lambda_memory_size             = 256
  lambda_reserved_concurrency    = 10

  # Attendance configuration
  attendance_session_duration    = 180  # 3 hours
  geolocation_radius_meters      = 100
  enable_geolocation_validation  = true
  qr_code_expiry_minutes         = 15
  attendance_grace_period_minutes = 10
  enable_attendance_analytics    = true

  # CloudWatch configuration
  log_retention_days             = local.dev_config.log_retention_days
  enable_xray_tracing           = true

  # Notification configuration
  enable_attendance_notifications = true
  notification_topic_arn         = ""  # Add SNS topic ARN when notifications module is implemented

  # Reporting configuration
  report_schedule_expression     = "cron(0 18 * * ? *)"  # Daily at 6 PM
  enable_csv_export             = true
  report_s3_bucket              = ""  # Add S3 bucket when needed

  # Security configuration
  kms_key_arn                   = aws_kms_key.main.arn

  # Tags
  tags = local.common_tags

  depends_on = [
    module.networking,
    module.authentication,
    aws_kms_key.main
  ]
}

# =============================================================================
# Marks Management Module
# =============================================================================

module "marks" {
  count  = var.enable_marks ? 1 : 0
  source = "../../modules/marks"

  # Basic configuration
  environment  = local.environment
  project_name = var.project_name

  # Networking
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  database_subnet_ids  = module.networking.database_subnet_ids
  public_subnet_ids    = module.networking.public_subnet_ids

  # Database configuration
  db_name                     = var.db_name
  db_username                 = var.db_username
  db_password                 = var.db_password
  db_instance_class           = local.dev_config.instance_types.db_tier
  enable_multi_az             = false  # Single AZ for dev
  backup_retention_period     = local.dev_config.backup_retention
  enable_performance_insights = false  # Disabled for dev cost savings

  # EC2 configuration
  ec2_instance_type           = local.dev_config.instance_types.app_tier
  min_size                    = local.dev_config.scaling_config.min_capacity
  max_size                    = local.dev_config.scaling_config.max_capacity
  desired_capacity            = local.dev_config.scaling_config.desired_capacity
  ec2_key_pair_name           = ""  # No SSH key for dev

  # Application configuration
  app_port                    = 3000
  node_env                    = "development"

  # Security configuration
  allowed_cidr_blocks         = ["0.0.0.0/0"]  # Open for dev
  enable_waf                  = false  # Disabled for dev
  kms_key_arn                 = aws_kms_key.main.arn

  # Monitoring configuration
  enable_detailed_monitoring  = false  # Basic monitoring for dev
  log_retention_days          = local.dev_config.log_retention_days
  enable_enhanced_monitoring  = false  # Disabled for dev

  # Load balancer configuration
  enable_deletion_protection  = false  # Allow deletion in dev
  idle_timeout               = 60
  enable_http2               = true

  # Tags
  tags = local.common_tags

  depends_on = [
    module.networking,
    aws_kms_key.main
  ]
}

# =============================================================================
# Notifications Module
# =============================================================================

module "notifications" {
  count  = var.enable_notifications ? 1 : 0
  source = "../../modules/notifications"

  # Basic configuration
  project_name = var.project_name
  environment  = local.environment

  # Networking
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids

  # Security
  kms_key_arn = aws_kms_key.main.arn

  # SES Configuration
  ses_from_email                = "noreply@${var.project_name}.com"
  ses_from_name                 = "Education Platform"
  enable_ses_domain_verification = false  # Disabled for dev
  enable_ses_dkim               = false   # Disabled for dev
  allowed_sender_emails         = [
    "admin@${var.project_name}.com",
    "noreply@${var.project_name}.com"
  ]

  # SNS Configuration
  notification_topics = {
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

  enable_sms_notifications = false  # Disabled for dev cost savings
  sms_sender_id           = "EduPlatform"

  # Lambda Configuration
  lambda_runtime              = "nodejs18.x"
  lambda_timeout              = 30
  lambda_memory_size          = 256
  lambda_reserved_concurrency = 10
  enable_lambda_vpc           = true

  # Email Templates (using default templates from variables)
  email_templates = {
    welcome = {
      subject = "Welcome to {{platform_name}}"
      html    = "<h1>Welcome {{user_name}}!</h1><p>Thank you for joining our education platform.</p><p>You can now access all the features including courses, assignments, and more.</p>"
      text    = "Welcome {{user_name}}! Thank you for joining our education platform. You can now access all the features including courses, assignments, and more."
    }
    grade_update = {
      subject = "Grade Update for {{course_name}}"
      html    = "<h2>Grade Update</h2><p>Hello {{user_name}},</p><p>Your grade for {{assignment_name}} in {{course_name}} has been updated to <strong>{{grade}}</strong>.</p><p>Keep up the great work!</p>"
      text    = "Grade Update: Hello {{user_name}}, your grade for {{assignment_name}} in {{course_name}} has been updated to {{grade}}. Keep up the great work!"
    }
    attendance_reminder = {
      subject = "Class Reminder: {{class_name}}"
      html    = "<h2>Class Reminder</h2><p>Hello {{user_name}},</p><p>Don't forget about your {{class_name}} class scheduled for {{class_time}}.</p><p>Location: {{class_location}}</p>"
      text    = "Class Reminder: Hello {{user_name}}, don't forget about your {{class_name}} class scheduled for {{class_time}}. Location: {{class_location}}"
    }
    assignment_due = {
      subject = "Assignment Due Soon: {{assignment_name}}"
      html    = "<h2>Assignment Due Soon</h2><p>Hello {{user_name}},</p><p>Your assignment <strong>{{assignment_name}}</strong> for {{course_name}} is due on {{due_date}}.</p><p>Make sure to submit it on time!</p>"
      text    = "Assignment Due Soon: Hello {{user_name}}, your assignment {{assignment_name}} for {{course_name}} is due on {{due_date}}. Make sure to submit it on time!"
    }
  }

  # Notification Preferences
  default_notification_preferences = {
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

  # CloudWatch Configuration
  log_retention_days         = local.dev_config.log_retention_days
  enable_xray_tracing       = true
  enable_detailed_monitoring = false  # Disabled for dev cost savings

  # Security Configuration
  rate_limit_per_minute         = 20  # Higher limit for dev testing
  enable_notification_encryption = true

  # Integration Configuration
  user_pool_id = module.authentication.user_pool_id

  # Cost Optimization
  enable_cost_optimization  = true
  notification_batch_size   = 10
  enable_dead_letter_queue  = true

  # Tags
  tags = merge(local.common_tags, {
    Module = "notifications"
  })

  sns_tags = {
    Service = "sns"
    Purpose = "notifications"
  }

  ses_tags = {
    Service = "ses"
    Purpose = "email-notifications"
  }

  lambda_tags = {
    Runtime = "nodejs18.x"
    Purpose = "notification-processing"
  }

  depends_on = [
    module.networking,
    module.authentication,
    aws_kms_key.main
  ]
}

# =============================================================================
# Security Module
# =============================================================================

module "security" {
  count  = var.enable_security ? 1 : 0
  source = "../../modules/security"

  # Basic configuration
  project_name = var.project_name
  environment  = local.environment

  # Networking
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids

  # Integration with other modules
  api_gateway_id            = module.authentication.api_gateway_id
  cloudfront_distribution_id = module.static_hosting.cloudfront_distribution_id
  alb_arn                   = var.enable_marks ? module.marks[0].alb_arn : ""

  # WAF Configuration
  enable_waf = local.environment == "prod" ? true : false  # Enable WAF in production
  waf_scope  = "REGIONAL"
  
  waf_rules = {
    enable_rate_limiting     = true
    enable_geo_blocking      = false  # Disabled for global access
    enable_ip_reputation     = true
    enable_known_bad_inputs  = true
    enable_sql_injection     = true
    enable_xss_protection    = true
    enable_size_restrictions = true
  }

  rate_limit_requests = local.environment == "dev" ? 5000 : 2000
  blocked_countries   = []  # No geo-blocking for education platform
  ip_whitelist        = []  # No IP restrictions for public platform
  ip_blacklist        = []  # Managed by AWS reputation lists

  # IAM Configuration
  enable_iam_access_analyzer = true
  enable_password_policy     = true
  create_security_roles      = true

  password_policy = {
    minimum_password_length        = local.environment == "dev" ? 8 : 12
    require_lowercase_characters   = true
    require_uppercase_characters   = true
    require_numbers               = true
    require_symbols               = local.environment == "dev" ? false : true
    allow_users_to_change_password = true
    max_password_age              = local.environment == "dev" ? 0 : 90
    password_reuse_prevention     = local.environment == "dev" ? 0 : 12
  }

  # KMS Configuration
  kms_key_rotation_enabled   = true
  kms_key_deletion_window    = local.environment == "dev" ? 7 : 30
  create_additional_kms_keys = true

  # GuardDuty Configuration
  enable_guardduty                      = local.environment != "dev"  # Disabled in dev for cost
  guardduty_finding_publishing_frequency = "SIX_HOURS"
  enable_guardduty_s3_protection        = local.environment != "dev"
  enable_guardduty_malware_protection   = false  # Additional cost

  # Security Hub Configuration
  enable_security_hub = local.environment != "dev"  # Disabled in dev for cost
  security_hub_standards = [
    "aws-foundational-security-standard",
    "cis-aws-foundations-benchmark"
  ]

  # Config Configuration
  enable_config              = local.environment != "dev"  # Disabled in dev for cost
  config_delivery_frequency  = "TwentyFour_Hours"

  # CloudTrail Configuration
  enable_cloudtrail                      = true
  cloudtrail_include_global_service_events = true
  cloudtrail_is_multi_region_trail        = local.environment != "dev"
  cloudtrail_enable_log_file_validation   = true
  cloudtrail_s3_key_prefix               = "cloudtrail-logs"

  # VPC Security Configuration
  enable_vpc_flow_logs     = true
  vpc_flow_logs_retention  = local.dev_config.log_retention_days
  enable_network_acls      = local.environment != "dev"  # Simplified for dev

  # Secrets Manager Configuration
  enable_secrets_manager  = true
  secrets_recovery_window = local.environment == "dev" ? 7 : 30

  # Monitoring and Alerting
  enable_security_monitoring    = true
  security_notification_email   = ""  # Set this to receive security alerts
  enable_cost_anomaly_detection = local.environment != "dev"

  # Compliance Configuration
  compliance_framework      = "general"
  enable_encryption_at_rest = true
  enable_encryption_in_transit = true

  # Cost Optimization
  enable_cost_optimization = true
  security_budget_limit    = local.environment == "dev" ? 50 : 200

  # Tags
  tags = merge(local.common_tags, {
    Module = "security"
  })

  security_tags = {
    SecurityLevel = local.environment == "prod" ? "high" : "medium"
    Compliance    = "general"
    DataClass     = "internal"
  }

  depends_on = [
    module.networking,
    module.authentication,
    module.static_hosting,
    aws_kms_key.main
  ]
}

# =============================================================================
# Monitoring Module
# =============================================================================

module "monitoring" {
  count  = var.enable_monitoring ? 1 : 0
  source = "../../modules/monitoring"

  # Basic configuration
  project_name = var.project_name
  environment  = local.environment

  # CloudWatch configuration
  enable_detailed_monitoring = local.environment != "dev"  # Disabled in dev for cost
  dashboard_name            = "${local.name_prefix}-monitoring-dashboard"
  log_retention_days        = local.dev_config.log_retention_days
  alarm_notification_email  = ""  # Set this to receive alarm notifications

  # Cost monitoring
  enable_cost_monitoring    = true
  monthly_budget_limit      = local.environment == "dev" ? 200 : 1000
  enable_cost_anomaly_detection = local.environment != "dev"

  # CloudTrail configuration
  enable_cloudtrail                      = true
  enable_cloudtrail_log_file_validation  = true
  cloudtrail_include_global_service_events = true
  cloudtrail_is_multi_region_trail        = local.environment != "dev"
  enable_cloudtrail_data_events          = local.environment != "dev"

  # X-Ray configuration
  enable_xray_tracing = local.environment != "dev"  # Disabled in dev for cost
  xray_sampling_rate  = local.environment == "dev" ? 0.1 : 0.05

  # Integration with other modules
  vpc_id                     = module.networking.vpc_id
  api_gateway_id             = module.authentication.api_gateway_id
  api_gateway_stage_name     = var.environment
  
  # Lambda functions to monitor
  lambda_function_names = compact([
    var.enable_chat ? "${local.name_prefix}-chat-resolver" : "",
    var.enable_chat ? "${local.name_prefix}-message-processor" : "",
    var.enable_chat ? "${local.name_prefix}-chat-auth-resolver" : "",
    var.enable_video ? "${local.name_prefix}-video-processor" : "",
    var.enable_video ? "${local.name_prefix}-video-upload-handler" : "",
    var.enable_attendance ? "${local.name_prefix}-attendance-tracker" : "",
    var.enable_attendance ? "${local.name_prefix}-attendance-reporter" : "",
    var.enable_notifications ? "${local.name_prefix}-notification-handler" : "",
    var.enable_notifications ? "${local.name_prefix}-email-sender" : "",
    "${local.name_prefix}-auth-handler",
    "${local.name_prefix}-pre-signup",
    "${local.name_prefix}-post-confirmation"
  ])

  # DynamoDB tables to monitor
  dynamodb_table_names = compact([
    var.enable_chat ? "${local.name_prefix}-chat-messages" : "",
    var.enable_chat ? "${local.name_prefix}-chat-rooms" : "",
    var.enable_chat ? "${local.name_prefix}-user-presence" : "",
    var.enable_attendance ? "${local.name_prefix}-attendance" : "",
    var.enable_attendance ? "${local.name_prefix}-classes" : "",
    var.enable_notifications ? "${local.name_prefix}-notification-preferences" : ""
  ])

  # S3 buckets to monitor
  s3_bucket_names = compact([
    module.static_hosting.s3_bucket_name,
    var.enable_video && length(module.video) > 0 ? module.video[0].raw_video_bucket_name : "",
    var.enable_video && length(module.video) > 0 ? module.video[0].transcoded_video_bucket_name : ""
  ])

  # CloudFront distributions to monitor
  cloudfront_distribution_ids = compact([
    module.static_hosting.cloudfront_distribution_id,
    var.enable_video && length(module.video) > 0 ? module.video[0].cloudfront_distribution_id : ""
  ])

  # RDS cluster to monitor
  rds_cluster_identifier = var.enable_marks && length(module.marks) > 0 ? module.marks[0].rds_cluster_identifier : ""

  # ALB to monitor
  alb_arn_suffix = var.enable_marks && length(module.marks) > 0 ? module.marks[0].alb_arn_suffix : ""

  # OpenSearch domain to monitor
  opensearch_domain_name = var.enable_chat && length(module.chat) > 0 ? module.chat[0].opensearch_domain_name : ""

  # Alerting configuration
  enable_high_error_rate_alarms = true
  error_rate_threshold         = var.environment == "dev" ? 10.0 : 5.0
  enable_high_latency_alarms   = true
  latency_threshold_ms         = var.environment == "dev" ? 10000 : 5000

  # Log Insights queries
  enable_log_insights_queries = true

  # Custom log groups
  custom_log_groups = {
    business_logic = {
      retention_in_days = local.dev_config.log_retention_days
    }
    integration = {
      retention_in_days = local.dev_config.log_retention_days
    }
  }

  # Tags
  tags = merge(local.common_tags, {
    Module = "monitoring"
  })

  depends_on = [
    module.networking,
    module.authentication,
    module.static_hosting,
    module.chat,
    module.video,
    module.attendance,
    module.marks,
    module.notifications,
    module.security,
    aws_kms_key.main
  ]
}

# =============================================================================
# S3 Bucket for Terraform State
# =============================================================================

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-terraform-state"
    Purpose     = "terraform-state-storage"
    Description = "S3 bucket for storing Terraform state files"
  })
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

# =============================================================================
# DynamoDB Table for Terraform State Locking
# =============================================================================

resource "aws_dynamodb_table" "terraform_locks" {
  name           = "${var.project_name}-terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-terraform-locks"
    Purpose     = "terraform-state-locking"
    Description = "DynamoDB table for Terraform state locking"
  })
}

# =============================================================================
# KMS Key for Encryption
# =============================================================================

resource "aws_kms_key" "main" {
  description             = "KMS key for ${local.name_prefix} encryption"
  deletion_window_in_days = 7  # Shorter window for dev
  
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-kms-key"
    Purpose     = "encryption"
    Description = "KMS key for encrypting sensitive data"
  })
}

resource "aws_kms_alias" "main" {
  name          = "alias/${local.name_prefix}"
  target_key_id = aws_kms_key.main.key_id
}

# =============================================================================
# CloudWatch Log Groups for Application Logs
# =============================================================================

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/application/${local.name_prefix}"
  retention_in_days = local.dev_config.log_retention_days
  
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-app-logs"
    Purpose     = "application-logging"
    LogType     = "application"
  })
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.name_prefix}"
  retention_in_days = local.dev_config.log_retention_days
  
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-lambda-logs"
    Purpose     = "lambda-logging"
    LogType     = "lambda"
  })
}

# =============================================================================
# Parameter Store for Configuration
# =============================================================================

resource "aws_ssm_parameter" "environment_config" {
  name  = "/${var.project_name}/${local.environment}/config"
  type  = "String"
  value = jsonencode({
    environment    = local.environment
    vpc_id         = module.networking.vpc_id
    vpc_cidr       = module.networking.vpc_cidr_block
    public_subnets = module.networking.public_subnets
    private_subnets = module.networking.private_subnets
    database_subnets = module.networking.database_subnets
    security_groups = module.networking.security_groups
    region         = data.aws_region.current.name
    account_id     = data.aws_caller_identity.current.account_id
  })
  
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-environment-config"
    Purpose     = "configuration"
    Description = "Environment configuration parameters"
  })
}

resource "aws_ssm_parameter" "auth_config" {
  name  = "/${var.project_name}/${local.environment}/authentication/config"
  type  = "String"
  value = jsonencode({
    user_pool_id          = module.authentication.user_pool_id
    user_pool_client_id   = module.authentication.user_pool_client_id
    identity_pool_id      = module.authentication.identity_pool_id
    api_gateway_url       = module.authentication.api_gateway_invoke_url
    cognito_domain        = module.authentication.user_pool_domain
  })
  
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-auth-config"
    Purpose     = "authentication-configuration"
    Description = "Authentication configuration parameters"
  })
}

# =============================================================================
# IAM Role for EC2 Instances
# =============================================================================

resource "aws_iam_role" "ec2_role" {
  name = "${local.name_prefix}-ec2-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-ec2-role"
    Purpose     = "ec2-permissions"
    Description = "IAM role for EC2 instances"
  })
}

resource "aws_iam_role_policy" "ec2_policy" {
  name = "${local.name_prefix}-ec2-policy"
  role = aws_iam_role.ec2_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:DescribeParameters"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${local.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/application/${local.name_prefix}*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name
  
  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-ec2-profile"
    Purpose     = "ec2-instance-profile"
    Description = "Instance profile for EC2 instances"
  })
}

# =============================================================================
# Development Environment Outputs
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr_block
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.networking.public_subnets
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.networking.private_subnets
}

output "database_subnets" {
  description = "List of database subnet IDs"
  value       = module.networking.database_subnets
}

output "security_groups" {
  description = "Map of security group IDs"
  value       = module.networking.security_groups
}

output "database_subnet_group_id" {
  description = "ID of the database subnet group"
  value       = module.networking.database_subnet_group_id
}

output "kms_key_id" {
  description = "ID of the KMS key for encryption"
  value       = aws_kms_key.main.key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  value       = aws_kms_key.main.arn
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "ec2_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = aws_iam_role.ec2_role.arn
}

# Authentication outputs
output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = module.authentication.user_pool_id
}

output "user_pool_client_id" {
  description = "ID of the Cognito User Pool client"
  value       = module.authentication.user_pool_client_id
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = module.authentication.api_gateway_invoke_url
}

output "cognito_domain" {
  description = "Cognito User Pool domain"
  value       = module.authentication.user_pool_domain
}

# Static hosting outputs
output "website_url" {
  description = "Website URL"
  value       = module.static_hosting.website_url
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for website content"
  value       = module.static_hosting.s3_bucket_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.static_hosting.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = module.static_hosting.cloudfront_domain_name
}

# Chat module outputs
output "chat_appsync_api_url" {
  description = "AppSync GraphQL API URL for chat"
  value       = var.enable_chat ? module.chat[0].appsync_graphql_url : null
}

output "chat_appsync_realtime_url" {
  description = "AppSync real-time URL for chat subscriptions"
  value       = var.enable_chat ? module.chat[0].appsync_realtime_url : null
}

output "chat_messages_table" {
  description = "Name of the chat messages DynamoDB table"
  value       = var.enable_chat ? module.chat[0].dynamodb_table_names.chat_messages : null
}

output "chat_rooms_table" {
  description = "Name of the chat rooms DynamoDB table"
  value       = var.enable_chat ? module.chat[0].dynamodb_table_names.chat_rooms : null
}

output "chat_opensearch_domain" {
  description = "OpenSearch domain endpoint for chat message search"
  value       = var.enable_chat ? module.chat[0].opensearch_domain_endpoint : null
}

# Video module outputs
output "video_raw_bucket_name" {
  description = "Name of the S3 bucket for raw video uploads"
  value       = var.enable_video ? module.video[0].raw_video_bucket_name : null
}

output "video_transcoded_bucket_name" {
  description = "Name of the S3 bucket for transcoded videos"
  value       = var.enable_video ? module.video[0].transcoded_video_bucket_name : null
}

output "video_streaming_url" {
  description = "Base URL for video streaming"
  value       = var.enable_video ? module.video[0].video_streaming_url : null
}

output "video_processor_function_name" {
  description = "Name of the video processor Lambda function"
  value       = var.enable_video ? module.video[0].video_processor_function_name : null
}

output "presigned_url_function_name" {
  description = "Name of the presigned URL generator Lambda function"
  value       = var.enable_video ? module.video[0].presigned_url_generator_name : null
}

output "transcoder_pipeline_id" {
  description = "ID of the Elastic Transcoder pipeline"
  value       = var.enable_video ? module.video[0].transcoder_pipeline_id : null
}

# Attendance module outputs
output "attendance_table_name" {
  description = "Name of the attendance DynamoDB table"
  value       = var.enable_attendance ? module.attendance[0].attendance_table_name : null
}

output "classes_table_name" {
  description = "Name of the classes DynamoDB table"
  value       = var.enable_attendance ? module.attendance[0].classes_table_name : null
}

output "attendance_tracker_function_name" {
  description = "Name of the attendance tracker Lambda function"
  value       = var.enable_attendance ? module.attendance[0].attendance_tracker_function_name : null
}

output "attendance_reporter_function_name" {
  description = "Name of the attendance reporter Lambda function"
  value       = var.enable_attendance ? module.attendance[0].attendance_reporter_function_name : null
}

output "attendance_api_endpoints" {
  description = "Attendance API endpoints"
  value       = var.enable_attendance ? module.attendance[0].attendance_api_endpoints : {}
}

# Marks module outputs
output "marks_database_endpoint" {
  description = "RDS cluster endpoint for marks database"
  value       = var.enable_marks ? module.marks[0].rds_cluster_endpoint : null
  sensitive   = true
}

output "marks_application_url" {
  description = "Application Load Balancer URL for marks API"
  value       = var.enable_marks ? module.marks[0].application_url : null
}

output "marks_api_endpoints" {
  description = "Marks management API endpoints"
  value       = var.enable_marks ? module.marks[0].api_endpoints : {}
}

output "marks_auto_scaling_group" {
  description = "Auto Scaling Group name for marks application"
  value       = var.enable_marks ? module.marks[0].auto_scaling_group_name : null
}

output "marks_database_name" {
  description = "Name of the marks database"
  value       = var.enable_marks ? module.marks[0].rds_cluster_database_name : null
}

# Notifications module outputs
output "notification_topics" {
  description = "Map of SNS topic ARNs for notifications"
  value       = var.enable_notifications ? module.notifications[0].sns_topic_arns : {}
}

output "notification_lambda_functions" {
  description = "Map of notification Lambda function names"
  value       = var.enable_notifications ? module.notifications[0].lambda_function_names : {}
}

output "ses_configuration" {
  description = "SES configuration details"
  value       = var.enable_notifications ? module.notifications[0].notification_endpoints.ses_configuration : {}
}

output "notification_preferences_table" {
  description = "DynamoDB table for notification preferences"
  value       = var.enable_notifications ? module.notifications[0].notification_preferences_table : {}
}

output "notification_dashboard_url" {
  description = "CloudWatch dashboard URL for notifications"
  value       = var.enable_notifications ? module.notifications[0].cloudwatch_dashboard_url : null
}

# Security module outputs
output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = var.enable_security ? module.security[0].waf_web_acl_arn : null
}

output "security_roles" {
  description = "Map of security IAM role ARNs"
  value       = var.enable_security ? module.security[0].security_roles : {}
}

output "kms_keys" {
  description = "Map of KMS key ARNs"
  value       = var.enable_security ? module.security[0].kms_keys : {}
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = var.enable_security ? module.security[0].guardduty_detector_id : null
}

output "security_dashboard_url" {
  description = "URL of the security CloudWatch dashboard"
  value       = var.enable_security ? module.security[0].security_dashboard_url : null
}

output "cloudtrail_name" {
  description = "Name of the CloudTrail"
  value       = var.enable_security ? module.security[0].cloudtrail_name : null
}

output "secrets_manager_secrets" {
  description = "Map of Secrets Manager secret ARNs"
  value       = var.enable_security ? module.security[0].secrets_manager_secrets : {}
  sensitive   = true
}

# Monitoring module outputs
output "monitoring_dashboard_url" {
  description = "URL of the CloudWatch monitoring dashboard"
  value       = var.enable_monitoring ? module.monitoring[0].dashboard_url : null
}

output "monitoring_dashboard_name" {
  description = "Name of the CloudWatch monitoring dashboard"
  value       = var.enable_monitoring ? module.monitoring[0].dashboard_name : null
}

output "alarm_topic_arn" {
  description = "ARN of the SNS topic for monitoring alarms"
  value       = var.enable_monitoring ? module.monitoring[0].alarm_topic_arn : null
}

output "cost_alert_topic_arn" {
  description = "ARN of the SNS topic for cost alerts"
  value       = var.enable_monitoring ? module.monitoring[0].cost_alert_topic_arn : null
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail for audit logging"
  value       = var.enable_monitoring ? module.monitoring[0].cloudtrail_arn : null
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket name for CloudTrail logs"
  value       = var.enable_monitoring ? module.monitoring[0].cloudtrail_s3_bucket : null
}

output "xray_encryption_config" {
  description = "X-Ray encryption configuration"
  value       = var.enable_monitoring ? module.monitoring[0].xray_encryption_config : null
}

output "log_group_names" {
  description = "Names of created CloudWatch log groups"
  value       = var.enable_monitoring ? module.monitoring[0].log_group_names : {}
}

output "monitoring_alarms" {
  description = "Names of created CloudWatch alarms"
  value       = var.enable_monitoring ? module.monitoring[0].alarm_names : {}
}

output "budget_name" {
  description = "Name of the cost monitoring budget"
  value       = var.enable_monitoring ? module.monitoring[0].budget_name : null
}

output "cost_anomaly_detector_arn" {
  description = "ARN of the cost anomaly detector"
  value       = var.enable_monitoring ? module.monitoring[0].cost_anomaly_detector_arn : null
}

output "log_insights_queries" {
  description = "Names of CloudWatch Logs Insights saved queries"
  value       = var.enable_monitoring ? module.monitoring[0].log_insights_query_names : []
}

output "monitoring_summary" {
  description = "Summary of monitoring configuration"
  value       = var.enable_monitoring ? module.monitoring[0].monitoring_summary : {}
}

output "environment_info" {
  description = "Complete environment information"
  value = {
    environment     = local.environment
    name_prefix     = local.name_prefix
    region          = data.aws_region.current.name
    account_id      = data.aws_caller_identity.current.account_id
    vpc_id          = module.networking.vpc_id
    availability_zones = module.networking.availability_zones
    terraform_state_bucket = aws_s3_bucket.terraform_state.bucket
    terraform_locks_table  = aws_dynamodb_table.terraform_locks.name
    
    # Authentication info
    user_pool_id      = module.authentication.user_pool_id
    api_gateway_url   = module.authentication.api_gateway_invoke_url
    auth_endpoints = {
      login    = "${module.authentication.api_gateway_invoke_url}/auth/login"
      register = "${module.authentication.api_gateway_invoke_url}/auth/register"
      verify   = "${module.authentication.api_gateway_invoke_url}/auth/verify"
      refresh  = "${module.authentication.api_gateway_invoke_url}/auth/refresh"
    }
    
    # Static hosting info
    website_url              = module.static_hosting.website_url
    s3_bucket_name          = module.static_hosting.s3_bucket_name
    cloudfront_distribution_id = module.static_hosting.cloudfront_distribution_id
    deployment_info         = module.static_hosting.deployment_info
    
    # Chat info (if enabled)
    chat_enabled = var.enable_chat
    chat_info = var.enable_chat ? {
      appsync_api_url      = module.chat[0].appsync_graphql_url
      appsync_realtime_url = module.chat[0].appsync_realtime_url
      messages_table       = module.chat[0].dynamodb_table_names.chat_messages
      rooms_table          = module.chat[0].dynamodb_table_names.chat_rooms
      room_members_table   = module.chat[0].dynamodb_table_names.room_members
      user_presence_table  = module.chat[0].dynamodb_table_names.user_presence
      opensearch_endpoint  = module.chat[0].opensearch_domain_endpoint
      lambda_functions = {
        chat_resolver         = module.chat[0].lambda_function_names.chat_resolver
        message_processor     = module.chat[0].lambda_function_names.message_processor
        auth_resolver        = module.chat[0].lambda_function_names.chat_auth_resolver
      }
      features = {
        real_time_messaging = true
        message_search      = true
        room_management     = true
        user_presence       = true
        file_attachments    = true
      }
    } : null
    
    # Video info (if enabled)
    video_enabled = var.enable_video
    video_info = var.enable_video ? {
      raw_video_bucket     = module.video[0].raw_video_bucket_name
      transcoded_bucket    = module.video[0].transcoded_video_bucket_name
      streaming_url        = module.video[0].video_streaming_url
      processor_function   = module.video[0].video_processor_function_name
      upload_function      = module.video[0].presigned_url_generator_name
      transcoder_pipeline  = module.video[0].transcoder_pipeline_id
      supported_qualities  = ["1080p", "720p", "480p", "hls"]
      max_file_size_mb     = 2000
      upload_endpoints = {
        generate_upload_url = module.video[0].presigned_url_generator_name
        video_processor     = module.video[0].video_processor_function_name
      }
    } : null
    
    # Attendance info (if enabled)
    attendance_enabled = var.enable_attendance
    attendance_info = var.enable_attendance ? {
      attendance_table     = module.attendance[0].attendance_table_name
      classes_table        = module.attendance[0].classes_table_name
      tracker_function     = module.attendance[0].attendance_tracker_function_name
      reporter_function    = module.attendance[0].attendance_reporter_function_name
      api_endpoints        = module.attendance[0].attendance_api_endpoints
      configuration        = module.attendance[0].attendance_configuration
      features = {
        geolocation_validation = true
        qr_code_generation    = true
        attendance_analytics  = true
        csv_export           = true
        scheduled_reports    = true
        real_time_tracking   = true
      }
    } : null
    
    # Marks info (if enabled)
    marks_enabled = var.enable_marks
    marks_info = var.enable_marks ? {
      database_endpoint    = module.marks[0].rds_cluster_endpoint
      database_name        = module.marks[0].rds_cluster_database_name
      application_url      = module.marks[0].application_url
      api_endpoints        = module.marks[0].api_endpoints
      auto_scaling_group   = module.marks[0].auto_scaling_group_name
      load_balancer_dns    = module.marks[0].alb_dns_name
      features = {
        grade_management     = true
        course_management    = true
        student_analytics    = true
        grade_reports        = true
        auto_scaling        = true
        high_availability   = true
      }
    } : null
    
    # Notifications info (if enabled)
    notifications_enabled = var.enable_notifications
    notifications_info = var.enable_notifications ? {
      sns_topics           = module.notifications[0].sns_topic_arns
      lambda_functions     = module.notifications[0].lambda_function_names
      ses_from_email       = module.notifications[0].ses_from_email
      configuration_set    = module.notifications[0].ses_configuration_set_name
      preferences_table    = module.notifications[0].notification_preferences_table.name
      dashboard_url        = module.notifications[0].cloudwatch_dashboard_url
      features = {
        email_notifications  = true
        sms_notifications   = false
        push_notifications  = true
        template_support    = true
        batch_processing    = true
        rate_limiting       = true
        bounce_handling     = true
        analytics_tracking  = true
      }
    } : null
    
    # Security info (if enabled)
    security_enabled = var.enable_security
    security_info = var.enable_security ? {
      waf_web_acl_arn      = module.security[0].waf_web_acl_arn
      security_roles       = module.security[0].security_roles
      kms_keys            = module.security[0].kms_keys
      guardduty_detector  = module.security[0].guardduty_detector_id
      security_hub_account = module.security[0].security_hub_account_id
      cloudtrail_name     = module.security[0].cloudtrail_name
      config_recorder     = module.security[0].config_configuration_recorder_name
      secrets_arns        = module.security[0].secrets_manager_secrets
      dashboard_url       = module.security[0].security_dashboard_url
      features = {
        waf_protection      = true
        threat_detection    = true
        compliance_monitoring = true
        access_analysis     = true
        encryption_management = true
        secrets_management  = true
        audit_logging      = true
        cost_monitoring    = true
      }
    } : null
  }
}
