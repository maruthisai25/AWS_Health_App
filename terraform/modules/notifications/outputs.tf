# =============================================================================
# Notifications Module Outputs
# =============================================================================

# =============================================================================
# SNS Outputs
# =============================================================================

output "sns_topic_arns" {
  description = "Map of SNS topic ARNs"
  value = {
    for topic_name, topic in aws_sns_topic.notification_topics : topic_name => topic.arn
  }
}

output "sns_topic_names" {
  description = "Map of SNS topic names"
  value = {
    for topic_name, topic in aws_sns_topic.notification_topics : topic_name => topic.name
  }
}

output "sns_topic_ids" {
  description = "Map of SNS topic IDs"
  value = {
    for topic_name, topic in aws_sns_topic.notification_topics : topic_name => topic.id
  }
}

output "dead_letter_queue_arn" {
  description = "ARN of the dead letter queue"
  value       = var.enable_dead_letter_queue ? aws_sqs_queue.dead_letter_queue[0].arn : null
}

output "dead_letter_queue_url" {
  description = "URL of the dead letter queue"
  value       = var.enable_dead_letter_queue ? aws_sqs_queue.dead_letter_queue[0].url : null
}

# =============================================================================
# SES Outputs
# =============================================================================

output "ses_domain_identity" {
  description = "SES domain identity"
  value       = var.ses_domain != "" ? aws_ses_domain_identity.main[0].domain : null
}

output "ses_domain_verification_token" {
  description = "SES domain verification token"
  value       = var.ses_domain != "" && var.enable_ses_domain_verification ? aws_ses_domain_identity.main[0].verification_token : null
}

output "ses_dkim_tokens" {
  description = "SES DKIM tokens"
  value       = var.ses_domain != "" && var.enable_ses_dkim ? aws_ses_domain_dkim.main[0].dkim_tokens : []
}

output "ses_configuration_set_name" {
  description = "SES configuration set name"
  value       = aws_ses_configuration_set.main.name
}

output "ses_from_email" {
  description = "Default SES from email address"
  value       = var.ses_from_email
}

output "ses_verified_emails" {
  description = "List of verified SES email addresses"
  value       = [for email in aws_ses_email_identity.verified_emails : email.email]
}

# =============================================================================
# Lambda Function Outputs
# =============================================================================

output "lambda_function_names" {
  description = "Map of Lambda function names"
  value = {
    notification_handler = aws_lambda_function.notification_handler.function_name
    email_sender        = aws_lambda_function.email_sender.function_name
  }
}

output "lambda_function_arns" {
  description = "Map of Lambda function ARNs"
  value = {
    notification_handler = aws_lambda_function.notification_handler.arn
    email_sender        = aws_lambda_function.email_sender.arn
  }
}

output "lambda_function_invoke_arns" {
  description = "Map of Lambda function invoke ARNs"
  value = {
    notification_handler = aws_lambda_function.notification_handler.invoke_arn
    email_sender        = aws_lambda_function.email_sender.invoke_arn
  }
}

output "lambda_log_group_names" {
  description = "Map of Lambda CloudWatch log group names"
  value = {
    notification_handler = aws_cloudwatch_log_group.notification_handler.name
    email_sender        = aws_cloudwatch_log_group.email_sender.name
  }
}

# =============================================================================
# IAM Outputs
# =============================================================================

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "lambda_execution_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.name
}

output "sns_publish_policy_arn" {
  description = "ARN of the SNS publish policy"
  value       = aws_iam_policy.sns_publish_policy.arn
}

output "ses_send_policy_arn" {
  description = "ARN of the SES send policy"
  value       = aws_iam_policy.ses_send_policy.arn
}

# =============================================================================
# Email Template Outputs
# =============================================================================

output "email_template_names" {
  description = "List of created email template names"
  value       = [for template in aws_ses_template.email_templates : template.name]
}

output "email_template_subjects" {
  description = "Map of email template subjects"
  value = {
    for template_name, template in aws_ses_template.email_templates : template_name => template.subject
  }
}

# =============================================================================
# CloudWatch Outputs
# =============================================================================

output "cloudwatch_log_group_arns" {
  description = "Map of CloudWatch log group ARNs"
  value = {
    notification_handler = aws_cloudwatch_log_group.notification_handler.arn
    email_sender        = aws_cloudwatch_log_group.email_sender.arn
  }
}

output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.notifications.dashboard_name}"
}

# =============================================================================
# Integration Outputs
# =============================================================================

output "notification_endpoints" {
  description = "Map of notification service endpoints"
  value = {
    sns_topics = {
      for topic_name, topic in aws_sns_topic.notification_topics : topic_name => {
        arn         = topic.arn
        name        = topic.name
        display_name = topic.display_name
      }
    }
    lambda_functions = {
      notification_handler = {
        name        = aws_lambda_function.notification_handler.function_name
        arn         = aws_lambda_function.notification_handler.arn
        invoke_arn  = aws_lambda_function.notification_handler.invoke_arn
      }
      email_sender = {
        name        = aws_lambda_function.email_sender.function_name
        arn         = aws_lambda_function.email_sender.arn
        invoke_arn  = aws_lambda_function.email_sender.invoke_arn
      }
    }
    ses_configuration = {
      configuration_set = aws_ses_configuration_set.main.name
      from_email       = var.ses_from_email
      from_name        = var.ses_from_name
      domain          = var.ses_domain != "" ? var.ses_domain : null
    }
  }
}

output "notification_preferences_table" {
  description = "DynamoDB table for notification preferences"
  value = {
    name = aws_dynamodb_table.notification_preferences.name
    arn  = aws_dynamodb_table.notification_preferences.arn
  }
}

# =============================================================================
# Security Outputs
# =============================================================================

output "security_configuration" {
  description = "Security configuration details"
  value = {
    kms_key_arn              = var.kms_key_arn
    encryption_enabled       = var.enable_notification_encryption
    rate_limit_per_minute    = var.rate_limit_per_minute
    vpc_enabled             = var.enable_lambda_vpc
    security_group_id       = var.enable_lambda_vpc ? aws_security_group.lambda_sg[0].id : null
  }
}

# =============================================================================
# Cost Optimization Outputs
# =============================================================================

output "cost_optimization_features" {
  description = "Enabled cost optimization features"
  value = {
    cost_optimization_enabled = var.enable_cost_optimization
    batch_processing_enabled  = var.notification_batch_size > 1
    dead_letter_queue_enabled = var.enable_dead_letter_queue
    detailed_monitoring      = var.enable_detailed_monitoring
    lambda_reserved_concurrency = var.lambda_reserved_concurrency
  }
}

# =============================================================================
# Module Information
# =============================================================================

output "module_info" {
  description = "Module information and configuration"
  value = {
    module_name    = "notifications"
    environment    = var.environment
    project_name   = var.project_name
    lambda_runtime = var.lambda_runtime
    
    features_enabled = {
      email_notifications = true
      sms_notifications  = var.enable_sms_notifications
      push_notifications = true
      domain_verification = var.enable_ses_domain_verification
      dkim_enabled       = var.enable_ses_dkim
      vpc_deployment     = var.enable_lambda_vpc
      xray_tracing      = var.enable_xray_tracing
    }
    
    topics_configured = length(var.notification_topics)
    templates_configured = length(var.email_templates)
    
    deployment_info = {
      region           = data.aws_region.current.name
      account_id       = data.aws_caller_identity.current.account_id
      vpc_id          = var.vpc_id
      private_subnets = var.private_subnet_ids
    }
  }
}

# =============================================================================
# Data Sources for Outputs
# =============================================================================