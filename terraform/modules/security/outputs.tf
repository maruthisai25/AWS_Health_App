# =============================================================================
# Security Module Outputs
# =============================================================================

# =============================================================================
# WAF Outputs
# =============================================================================

output "waf_web_acl_id" {
  description = "ID of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].id : null
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : null
}

output "waf_web_acl_name" {
  description = "Name of the WAF Web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].name : null
}

output "waf_ip_set_ids" {
  description = "Map of WAF IP Set IDs"
  value = var.enable_waf ? {
    whitelist = aws_wafv2_ip_set.whitelist[0].id
    blacklist = aws_wafv2_ip_set.blacklist[0].id
  } : {}
}

# =============================================================================
# IAM Outputs
# =============================================================================

output "iam_access_analyzer_arn" {
  description = "ARN of the IAM Access Analyzer"
  value       = var.enable_iam_access_analyzer ? aws_accessanalyzer_analyzer.main[0].arn : null
}

output "security_roles" {
  description = "Map of security IAM role ARNs"
  value = var.create_security_roles ? {
    security_admin    = aws_iam_role.security_admin[0].arn
    security_auditor  = aws_iam_role.security_auditor[0].arn
    incident_response = aws_iam_role.incident_response[0].arn
  } : {}
}

output "password_policy_enabled" {
  description = "Whether IAM password policy is enabled"
  value       = var.enable_password_policy
}

# =============================================================================
# KMS Outputs
# =============================================================================

output "kms_keys" {
  description = "Map of KMS key ARNs"
  value = var.create_additional_kms_keys ? {
    database    = aws_kms_key.database[0].arn
    s3          = aws_kms_key.s3[0].arn
    lambda      = aws_kms_key.lambda[0].arn
    secrets     = aws_kms_key.secrets[0].arn
    cloudwatch  = aws_kms_key.cloudwatch[0].arn
  } : {}
}

output "kms_key_aliases" {
  description = "Map of KMS key alias names"
  value = var.create_additional_kms_keys ? {
    database    = aws_kms_alias.database[0].name
    s3          = aws_kms_alias.s3[0].name
    lambda      = aws_kms_alias.lambda[0].name
    secrets     = aws_kms_alias.secrets[0].name
    cloudwatch  = aws_kms_alias.cloudwatch[0].name
  } : {}
}

# =============================================================================
# GuardDuty Outputs
# =============================================================================

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].id : null
}

output "guardduty_detector_arn" {
  description = "ARN of the GuardDuty detector"
  value       = var.enable_guardduty ? aws_guardduty_detector.main[0].arn : null
}

# =============================================================================
# Security Hub Outputs
# =============================================================================

output "security_hub_account_id" {
  description = "Security Hub account ID"
  value       = var.enable_security_hub ? aws_securityhub_account.main[0].id : null
}

output "security_hub_standards" {
  description = "List of enabled Security Hub standards"
  value       = var.enable_security_hub ? [for std in aws_securityhub_standards_subscription.standards : std.standards_arn] : []
}

# =============================================================================
# Config Outputs
# =============================================================================

output "config_configuration_recorder_name" {
  description = "Name of the Config configuration recorder"
  value       = var.enable_config ? aws_config_configuration_recorder.main[0].name : null
}

output "config_delivery_channel_name" {
  description = "Name of the Config delivery channel"
  value       = var.enable_config ? aws_config_delivery_channel.main[0].name : null
}

output "config_s3_bucket_name" {
  description = "Name of the Config S3 bucket"
  value       = var.enable_config ? aws_s3_bucket.config[0].bucket : null
}

# =============================================================================
# CloudTrail Outputs
# =============================================================================

output "cloudtrail_name" {
  description = "Name of the CloudTrail"
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].name : null
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = var.enable_cloudtrail ? aws_cloudtrail.main[0].arn : null
}

output "cloudtrail_s3_bucket_name" {
  description = "Name of the CloudTrail S3 bucket"
  value       = var.enable_cloudtrail ? aws_s3_bucket.cloudtrail[0].bucket : null
}

# =============================================================================
# VPC Security Outputs
# =============================================================================

output "vpc_flow_logs_log_group" {
  description = "CloudWatch log group for VPC Flow Logs"
  value       = var.enable_vpc_flow_logs ? aws_cloudwatch_log_group.vpc_flow_logs[0].name : null
}

output "network_acl_ids" {
  description = "Map of Network ACL IDs"
  value = var.enable_network_acls ? {
    public  = aws_network_acl.public[0].id
    private = aws_network_acl.private[0].id
  } : {}
}

# =============================================================================
# Secrets Manager Outputs
# =============================================================================

output "secrets_manager_secrets" {
  description = "Map of Secrets Manager secret ARNs"
  value = var.enable_secrets_manager ? {
    database_credentials = aws_secretsmanager_secret.database_credentials[0].arn
    api_keys            = aws_secretsmanager_secret.api_keys[0].arn
    encryption_keys     = aws_secretsmanager_secret.encryption_keys[0].arn
  } : {}
}

# =============================================================================
# Monitoring Outputs
# =============================================================================

output "security_sns_topic_arn" {
  description = "ARN of the security notifications SNS topic"
  value       = var.enable_security_monitoring ? aws_sns_topic.security_notifications[0].arn : null
}

output "security_dashboard_url" {
  description = "URL of the security CloudWatch dashboard"
  value       = var.enable_security_monitoring ? "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.security[0].dashboard_name}" : null
}

output "cost_anomaly_detector_arn" {
  description = "ARN of the cost anomaly detector"
  value       = var.enable_cost_anomaly_detection ? aws_ce_anomaly_detector.security_costs[0].arn : null
}

# =============================================================================
# Compliance Outputs
# =============================================================================

output "compliance_configuration" {
  description = "Compliance configuration details"
  value = {
    framework                = var.compliance_framework
    encryption_at_rest      = var.enable_encryption_at_rest
    encryption_in_transit   = var.enable_encryption_in_transit
    password_policy_enabled = var.enable_password_policy
    access_analyzer_enabled = var.enable_iam_access_analyzer
    guardduty_enabled      = var.enable_guardduty
    security_hub_enabled   = var.enable_security_hub
    config_enabled         = var.enable_config
    cloudtrail_enabled     = var.enable_cloudtrail
  }
}

# =============================================================================
# Security Summary
# =============================================================================

output "security_summary" {
  description = "Summary of security features enabled"
  value = {
    waf_protection = {
      enabled              = var.enable_waf
      rate_limiting       = var.waf_rules.enable_rate_limiting
      geo_blocking        = var.waf_rules.enable_geo_blocking
      sql_injection       = var.waf_rules.enable_sql_injection
      xss_protection      = var.waf_rules.enable_xss_protection
      ip_reputation       = var.waf_rules.enable_ip_reputation
    }
    
    identity_security = {
      access_analyzer     = var.enable_iam_access_analyzer
      password_policy     = var.enable_password_policy
      security_roles      = var.create_security_roles
    }
    
    encryption = {
      kms_key_rotation    = var.kms_key_rotation_enabled
      additional_keys     = var.create_additional_kms_keys
      at_rest_encryption  = var.enable_encryption_at_rest
      in_transit_encryption = var.enable_encryption_in_transit
    }
    
    threat_detection = {
      guardduty           = var.enable_guardduty
      security_hub        = var.enable_security_hub
      s3_protection       = var.enable_guardduty_s3_protection
      malware_protection  = var.enable_guardduty_malware_protection
    }
    
    compliance_monitoring = {
      config              = var.enable_config
      cloudtrail          = var.enable_cloudtrail
      vpc_flow_logs       = var.enable_vpc_flow_logs
      secrets_manager     = var.enable_secrets_manager
    }
    
    cost_management = {
      cost_optimization   = var.enable_cost_optimization
      anomaly_detection   = var.enable_cost_anomaly_detection
      budget_limit        = var.security_budget_limit
    }
  }
}

# =============================================================================
# Integration Information
# =============================================================================

output "integration_endpoints" {
  description = "Security service integration endpoints"
  value = {
    waf_web_acl_arn     = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : null
    kms_keys            = var.create_additional_kms_keys ? {
      database    = aws_kms_key.database[0].arn
      s3          = aws_kms_key.s3[0].arn
      lambda      = aws_kms_key.lambda[0].arn
      secrets     = aws_kms_key.secrets[0].arn
      cloudwatch  = aws_kms_key.cloudwatch[0].arn
    } : {}
    security_topic_arn  = var.enable_security_monitoring ? aws_sns_topic.security_notifications[0].arn : null
    secrets_arns        = var.enable_secrets_manager ? {
      database_credentials = aws_secretsmanager_secret.database_credentials[0].arn
      api_keys            = aws_secretsmanager_secret.api_keys[0].arn
      encryption_keys     = aws_secretsmanager_secret.encryption_keys[0].arn
    } : {}
  }
}

# =============================================================================
# Module Information
# =============================================================================

output "module_info" {
  description = "Security module information"
  value = {
    module_name     = "security"
    environment     = var.environment
    project_name    = var.project_name
    compliance_framework = var.compliance_framework
    
    deployment_info = {
      region      = data.aws_region.current.name
      account_id  = data.aws_caller_identity.current.account_id
      vpc_id      = var.vpc_id
    }
    
    features_enabled = {
      waf                    = var.enable_waf
      iam_access_analyzer    = var.enable_iam_access_analyzer
      guardduty             = var.enable_guardduty
      security_hub          = var.enable_security_hub
      config                = var.enable_config
      cloudtrail            = var.enable_cloudtrail
      vpc_flow_logs         = var.enable_vpc_flow_logs
      secrets_manager       = var.enable_secrets_manager
      security_monitoring   = var.enable_security_monitoring
      cost_anomaly_detection = var.enable_cost_anomaly_detection
    }
    
    cost_optimization = {
      enabled       = var.enable_cost_optimization
      budget_limit  = var.security_budget_limit
    }
  }
}

# =============================================================================
# Data Sources
# =============================================================================