# =============================================================================
# SES Configuration for Email Notifications
# =============================================================================

# =============================================================================
# SES Domain Identity
# =============================================================================

resource "aws_ses_domain_identity" "main" {
  count = var.ses_domain != "" ? 1 : 0

  domain = var.ses_domain
}

resource "aws_ses_domain_identity_verification" "main" {
  count = var.ses_domain != "" && var.enable_ses_domain_verification ? 1 : 0

  domain = aws_ses_domain_identity.main[0].id

  depends_on = [aws_route53_record.ses_verification]
}

# =============================================================================
# Route53 Records for SES Domain Verification
# =============================================================================

data "aws_route53_zone" "main" {
  count = var.ses_domain != "" && var.enable_ses_domain_verification ? 1 : 0

  name         = var.ses_domain
  private_zone = false
}

resource "aws_route53_record" "ses_verification" {
  count = var.ses_domain != "" && var.enable_ses_domain_verification ? 1 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "_amazonses.${var.ses_domain}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.main[0].verification_token]
}

# =============================================================================
# SES DKIM Configuration
# =============================================================================

resource "aws_ses_domain_dkim" "main" {
  count = var.ses_domain != "" && var.enable_ses_dkim ? 1 : 0

  domain = aws_ses_domain_identity.main[0].domain
}

resource "aws_route53_record" "ses_dkim" {
  count = var.ses_domain != "" && var.enable_ses_dkim ? 3 : 0

  zone_id = data.aws_route53_zone.main[0].zone_id
  name    = "${aws_ses_domain_dkim.main[0].dkim_tokens[count.index]}._domainkey.${var.ses_domain}"
  type    = "CNAME"
  ttl     = "600"
  records = ["${aws_ses_domain_dkim.main[0].dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# =============================================================================
# SES Email Identity for Development
# =============================================================================

resource "aws_ses_email_identity" "verified_emails" {
  for_each = toset(var.allowed_sender_emails)

  email = each.value
}

# =============================================================================
# SES Configuration Set
# =============================================================================

resource "aws_ses_configuration_set" "main" {
  name = "${var.project_name}-${var.environment}-config-set"

  delivery_options {
    tls_policy = "Require"
  }

  reputation_metrics_enabled = true
}

# =============================================================================
# SES Event Destinations
# =============================================================================

resource "aws_ses_event_destination" "bounce" {
  name                   = "bounce-destination"
  configuration_set_name = aws_ses_configuration_set.main.name
  enabled                = true
  matching_types         = ["bounce"]

  sns_destination {
    topic_arn = aws_sns_topic.notification_topics["system"].arn
  }
}

resource "aws_ses_event_destination" "complaint" {
  name                   = "complaint-destination"
  configuration_set_name = aws_ses_configuration_set.main.name
  enabled                = true
  matching_types         = ["complaint"]

  sns_destination {
    topic_arn = aws_sns_topic.notification_topics["system"].arn
  }
}

resource "aws_ses_event_destination" "delivery" {
  name                   = "delivery-destination"
  configuration_set_name = aws_ses_configuration_set.main.name
  enabled                = true
  matching_types         = ["delivery"]

  cloudwatch_destination {
    default_value  = "0"
    dimension_name = "EmailAddress"
    value_source   = "emailAddress"
  }
}

# =============================================================================
# SES Email Templates
# =============================================================================

resource "aws_ses_template" "email_templates" {
  for_each = var.email_templates

  name    = "${var.project_name}-${var.environment}-${each.key}"
  subject = each.value.subject
  html    = each.value.html
  text    = each.value.text
}

# =============================================================================
# SES Receipt Rules (for handling bounces and complaints)
# =============================================================================

resource "aws_ses_receipt_rule_set" "main" {
  rule_set_name = "${var.project_name}-${var.environment}-receipt-rules"
}

resource "aws_ses_receipt_rule" "bounce_handler" {
  name          = "bounce-handler"
  rule_set_name = aws_ses_receipt_rule_set.main.rule_set_name
  recipients    = ["bounce@${var.ses_domain}"]
  enabled       = var.ses_domain != ""
  scan_enabled  = true

  dynamic "sns_action" {
    for_each = var.ses_domain != "" ? [1] : []
    content {
      topic_arn = aws_sns_topic.notification_topics["system"].arn
      position  = 1
    }
  }

  depends_on = [aws_ses_domain_identity.main]
}

# =============================================================================
# CloudWatch Metrics for SES
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "ses_bounce_rate" {
  count = var.enable_detailed_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-ses-bounce-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Bounce"
  namespace           = "AWS/SES"
  period              = "300"
  statistic           = "Average"
  threshold           = "0.05"  # 5% bounce rate threshold
  alarm_description   = "This metric monitors SES bounce rate"
  alarm_actions       = [aws_sns_topic.notification_topics["system"].arn]

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-ses-bounce-rate-alarm"
    Purpose     = "monitoring"
    MetricType  = "bounce-rate"
    Module      = "notifications"
  })
}

resource "aws_cloudwatch_metric_alarm" "ses_complaint_rate" {
  count = var.enable_detailed_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-ses-complaint-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Complaint"
  namespace           = "AWS/SES"
  period              = "300"
  statistic           = "Average"
  threshold           = "0.001"  # 0.1% complaint rate threshold
  alarm_description   = "This metric monitors SES complaint rate"
  alarm_actions       = [aws_sns_topic.notification_topics["system"].arn]

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-ses-complaint-rate-alarm"
    Purpose     = "monitoring"
    MetricType  = "complaint-rate"
    Module      = "notifications"
  })
}

# =============================================================================
# SES Sending Statistics
# =============================================================================

resource "aws_cloudwatch_log_group" "ses_logs" {
  name              = "/aws/ses/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-ses-logs"
    Purpose     = "ses-logging"
    Module      = "notifications"
  })
}

# =============================================================================
# SES Identity Policies
# =============================================================================

resource "aws_ses_identity_policy" "domain_policy" {
  count = var.ses_domain != "" ? 1 : 0

  identity = aws_ses_domain_identity.main[0].arn
  name     = "${var.project_name}-${var.environment}-domain-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSendingFromLambda"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_execution_role.arn
        }
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
          "ses:SendTemplatedEmail"
        ]
        Resource = aws_ses_domain_identity.main[0].arn
        Condition = {
          StringEquals = {
            "ses:FromAddress" = [var.ses_from_email]
          }
        }
      }
    ]
  })
}

resource "aws_ses_identity_policy" "email_policies" {
  for_each = aws_ses_email_identity.verified_emails

  identity = each.value.arn
  name     = "${var.project_name}-${var.environment}-email-policy-${replace(each.key, "@", "-at-")}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSendingFromLambda"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_execution_role.arn
        }
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
          "ses:SendTemplatedEmail"
        ]
        Resource = each.value.arn
        Condition = {
          StringEquals = {
            "ses:FromAddress" = [each.key]
          }
        }
      }
    ]
  })
}

# =============================================================================
# SES Suppression List Management
# =============================================================================

resource "aws_sesv2_account_suppression_attributes" "main" {
  suppressed_reasons = ["BOUNCE", "COMPLAINT"]
}

resource "aws_sesv2_account_vdm_attributes" "main" {
  vdm_enabled = "ENABLED"

  dashboard_attributes {
    engagement_metrics = "ENABLED"
  }

  guardian_attributes {
    optimized_shared_delivery = "ENABLED"
  }
}