# =============================================================================
# Security Monitoring and Alerting
# =============================================================================

# =============================================================================
# GuardDuty
# =============================================================================

resource "aws_guardduty_detector" "main" {
  count = var.enable_guardduty ? 1 : 0

  enable                       = true
  finding_publishing_frequency = var.guardduty_finding_publishing_frequency

  datasources {
    s3_logs {
      enable = var.enable_guardduty_s3_protection
    }
    kubernetes {
      audit_logs {
        enable = false  # Not using EKS in this project
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = var.enable_guardduty_malware_protection
        }
      }
    }
  }

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-guardduty"
    Purpose     = "threat-detection"
    Module      = "security"
  })
}

# =============================================================================
# Security Hub
# =============================================================================

resource "aws_securityhub_account" "main" {
  count = var.enable_security_hub ? 1 : 0

  enable_default_standards = true
}

resource "aws_securityhub_standards_subscription" "standards" {
  for_each = var.enable_security_hub ? toset(var.security_hub_standards) : []

  standards_arn = "arn:aws:securityhub:::standard/${each.key}"
  depends_on    = [aws_securityhub_account.main]
}

# =============================================================================
# AWS Config
# =============================================================================

resource "aws_s3_bucket" "config" {
  count = var.enable_config ? 1 : 0

  bucket        = "${var.project_name}-${var.environment}-config-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.environment == "dev" ? true : false

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-config-bucket"
    Purpose     = "config-storage"
    Module      = "security"
  })
}

resource "aws_s3_bucket_versioning" "config" {
  count = var.enable_config ? 1 : 0

  bucket = aws_s3_bucket.config[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "config" {
  count = var.enable_config ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = var.create_additional_kms_keys ? aws_kms_key.s3[0].arn : null
        sse_algorithm     = var.create_additional_kms_keys ? "aws:kms" : "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_policy" "config" {
  count = var.enable_config ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.config[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"     = "bucket-owner-full-control"
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_config_configuration_recorder" "main" {
  count = var.enable_config ? 1 : 0

  name     = "${var.project_name}-${var.environment}-config-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  depends_on = [aws_config_delivery_channel.main]
}

resource "aws_config_delivery_channel" "main" {
  count = var.enable_config ? 1 : 0

  name           = "${var.project_name}-${var.environment}-config-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config[0].bucket

  snapshot_delivery_properties {
    delivery_frequency = var.config_delivery_frequency
  }
}

# =============================================================================
# CloudTrail
# =============================================================================

resource "aws_s3_bucket" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket        = "${var.project_name}-${var.environment}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.environment == "dev" ? true : false

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-cloudtrail-bucket"
    Purpose     = "cloudtrail-storage"
    Module      = "security"
  })
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = var.create_additional_kms_keys ? aws_kms_key.s3[0].arn : null
        sse_algorithm     = var.create_additional_kms_keys ? "aws:kms" : "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  bucket = aws_s3_bucket.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${var.project_name}-${var.environment}-cloudtrail"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${var.project_name}-${var.environment}-cloudtrail"
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  name              = "/aws/cloudtrail/${var.project_name}-${var.environment}"
  retention_in_days = var.vpc_flow_logs_retention
  kms_key_id        = var.create_additional_kms_keys ? aws_kms_key.cloudwatch[0].arn : null

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-cloudtrail-logs"
    Purpose     = "cloudtrail-logging"
    Module      = "security"
  })
}

resource "aws_cloudtrail" "main" {
  count = var.enable_cloudtrail ? 1 : 0

  name           = "${var.project_name}-${var.environment}-cloudtrail"
  s3_bucket_name = aws_s3_bucket.cloudtrail[0].bucket
  s3_key_prefix  = var.cloudtrail_s3_key_prefix

  include_global_service_events = var.cloudtrail_include_global_service_events
  is_multi_region_trail        = var.cloudtrail_is_multi_region_trail
  enable_log_file_validation   = var.cloudtrail_enable_log_file_validation

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail[0].arn

  kms_key_id = var.create_additional_kms_keys ? aws_kms_key.s3[0].arn : null

  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    exclude_management_event_sources = []

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/*"]
    }

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda:*"]
    }
  }

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-cloudtrail"
    Purpose     = "audit-logging"
    Module      = "security"
  })

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# =============================================================================
# VPC Flow Logs
# =============================================================================

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name              = "/aws/vpc/flowlogs/${var.project_name}-${var.environment}"
  retention_in_days = var.vpc_flow_logs_retention
  kms_key_id        = var.create_additional_kms_keys ? aws_kms_key.cloudwatch[0].arn : null

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-vpc-flow-logs"
    Purpose     = "vpc-flow-logging"
    Module      = "security"
  })
}

resource "aws_flow_log" "vpc" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.vpc_flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = var.vpc_id

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-vpc-flow-log"
    Purpose     = "vpc-flow-logging"
    Module      = "security"
  })
}

# =============================================================================
# Security Notifications
# =============================================================================

resource "aws_sns_topic" "security_notifications" {
  count = var.enable_security_monitoring ? 1 : 0

  name         = "${var.project_name}-${var.environment}-security-notifications"
  display_name = "Security Notifications"

  kms_master_key_id = var.create_additional_kms_keys ? aws_kms_key.sns[0].id : null

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-security-notifications"
    Purpose     = "security-alerting"
    Module      = "security"
  })
}

resource "aws_sns_topic_subscription" "security_email" {
  count = var.enable_security_monitoring && var.security_notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.security_notifications[0].arn
  protocol  = "email"
  endpoint  = var.security_notification_email
}

# =============================================================================
# CloudWatch Dashboard
# =============================================================================

resource "aws_cloudwatch_dashboard" "security" {
  count = var.enable_security_monitoring ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-security"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = concat(
            var.enable_waf ? [
              ["AWS/WAFV2", "AllowedRequests", "WebACL", "${var.project_name}-${var.environment}-web-acl", "Region", data.aws_region.current.name, "Rule", "ALL"],
              [".", "BlockedRequests", ".", ".", ".", ".", ".", "."]
            ] : [],
            var.enable_guardduty ? [
              ["AWS/GuardDuty", "FindingCount", "DetectorId", var.enable_guardduty ? aws_guardduty_detector.main[0].id : ""]
            ] : []
          )
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Security Metrics"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          query   = "SOURCE '/aws/cloudtrail/${var.project_name}-${var.environment}' | fields @timestamp, eventName, sourceIPAddress, userIdentity.type\n| filter eventName like /Delete/ or eventName like /Terminate/ or eventName like /Stop/\n| sort @timestamp desc\n| limit 20"
          region  = data.aws_region.current.name
          title   = "Recent High-Risk API Calls"
          view    = "table"
        }
      }
    ]
  })
}

# =============================================================================
# Cost Anomaly Detection
# =============================================================================

resource "aws_ce_anomaly_detector" "security_costs" {
  count = var.enable_cost_anomaly_detection ? 1 : 0

  name         = "${var.project_name}-${var.environment}-security-costs"
  monitor_type = "DIMENSIONAL"

  specification = jsonencode({
    Dimension = "SERVICE"
    MatchOptions = ["EQUALS"]
    Values = [
      "Amazon GuardDuty",
      "AWS Security Hub",
      "AWS Config",
      "AWS CloudTrail",
      "AWS WAF"
    ]
  })

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-security-cost-anomaly"
    Purpose     = "cost-monitoring"
    Module      = "security"
  })
}

resource "aws_ce_anomaly_subscription" "security_costs" {
  count = var.enable_cost_anomaly_detection && var.security_notification_email != "" ? 1 : 0

  name      = "${var.project_name}-${var.environment}-security-cost-alerts"
  frequency = "DAILY"
  
  monitor_arn_list = [
    aws_ce_anomaly_detector.security_costs[0].arn
  ]
  
  subscriber {
    type    = "EMAIL"
    address = var.security_notification_email
  }

  threshold_expression {
    and {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        values        = [tostring(var.security_budget_limit)]
        match_options = ["GREATER_THAN_OR_EQUAL"]
      }
    }
  }

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-security-cost-alerts"
    Purpose     = "cost-alerting"
    Module      = "security"
  })
}

# =============================================================================
# Data Sources
# =============================================================================