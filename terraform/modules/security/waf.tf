# =============================================================================
# AWS WAF Configuration
# =============================================================================

# =============================================================================
# WAF IP Sets
# =============================================================================

resource "aws_wafv2_ip_set" "whitelist" {
  count = var.enable_waf ? 1 : 0

  name               = "${var.project_name}-${var.environment}-whitelist"
  description        = "IP whitelist for ${var.project_name}"
  scope              = var.waf_scope
  ip_address_version = "IPV4"

  addresses = var.ip_whitelist

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-ip-whitelist"
    Purpose     = "waf-ip-whitelist"
    Module      = "security"
  })
}

resource "aws_wafv2_ip_set" "blacklist" {
  count = var.enable_waf ? 1 : 0

  name               = "${var.project_name}-${var.environment}-blacklist"
  description        = "IP blacklist for ${var.project_name}"
  scope              = var.waf_scope
  ip_address_version = "IPV4"

  addresses = length(var.ip_blacklist) > 0 ? var.ip_blacklist : ["192.0.2.44/32"]  # RFC 5737 test address

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-ip-blacklist"
    Purpose     = "waf-ip-blacklist"
    Module      = "security"
  })
}

# =============================================================================
# WAF Web ACL
# =============================================================================

resource "aws_wafv2_web_acl" "main" {
  count = var.enable_waf ? 1 : 0

  name  = "${var.project_name}-${var.environment}-web-acl"
  scope = var.waf_scope

  default_action {
    allow {}
  }

  # Rule 1: IP Whitelist (highest priority)
  dynamic "rule" {
    for_each = length(var.ip_whitelist) > 0 ? [1] : []
    content {
      name     = "IPWhitelistRule"
      priority = 1

      override_action {
        none {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.whitelist[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-ip-whitelist"
        sampled_requests_enabled   = true
      }

      action {
        allow {}
      }
    }
  }

  # Rule 2: IP Blacklist
  dynamic "rule" {
    for_each = length(var.ip_blacklist) > 0 ? [1] : []
    content {
      name     = "IPBlacklistRule"
      priority = 2

      override_action {
        none {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.blacklist[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-ip-blacklist"
        sampled_requests_enabled   = true
      }

      action {
        block {}
      }
    }
  }

  # Rule 3: Geographic Blocking
  dynamic "rule" {
    for_each = var.waf_rules.enable_geo_blocking && length(var.blocked_countries) > 0 ? [1] : []
    content {
      name     = "GeoBlockingRule"
      priority = 3

      override_action {
        none {}
      }

      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-geo-blocking"
        sampled_requests_enabled   = true
      }

      action {
        block {}
      }
    }
  }

  # Rule 4: Rate Limiting
  dynamic "rule" {
    for_each = var.waf_rules.enable_rate_limiting ? [1] : []
    content {
      name     = "RateLimitingRule"
      priority = 4

      override_action {
        none {}
      }

      statement {
        rate_based_statement {
          limit              = var.rate_limit_requests
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-rate-limiting"
        sampled_requests_enabled   = true
      }

      action {
        block {}
      }
    }
  }

  # Rule 5: AWS Managed Rules - Core Rule Set
  dynamic "rule" {
    for_each = var.waf_rules.enable_known_bad_inputs ? [1] : []
    content {
      name     = "AWSManagedRulesCoreRuleSet"
      priority = 5

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesCommonRuleSet"
          vendor_name = "AWS"

          # Exclude rules that might cause false positives in development
          dynamic "excluded_rule" {
            for_each = var.environment == "dev" ? ["SizeRestrictions_BODY", "GenericRFI_BODY"] : []
            content {
              name = excluded_rule.value
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-core-rules"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 6: AWS Managed Rules - Known Bad Inputs
  dynamic "rule" {
    for_each = var.waf_rules.enable_known_bad_inputs ? [1] : []
    content {
      name     = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = 6

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesKnownBadInputsRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-known-bad-inputs"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 7: AWS Managed Rules - SQL Injection
  dynamic "rule" {
    for_each = var.waf_rules.enable_sql_injection ? [1] : []
    content {
      name     = "AWSManagedRulesSQLiRuleSet"
      priority = 7

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesSQLiRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-sqli-rules"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 8: AWS Managed Rules - XSS Protection
  dynamic "rule" {
    for_each = var.waf_rules.enable_xss_protection ? [1] : []
    content {
      name     = "AWSManagedRulesXSSRuleSet"
      priority = 8

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesXSSRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-xss-rules"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 9: AWS Managed Rules - IP Reputation
  dynamic "rule" {
    for_each = var.waf_rules.enable_ip_reputation ? [1] : []
    content {
      name     = "AWSManagedRulesAmazonIpReputationList"
      priority = 9

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesAmazonIpReputationList"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-ip-reputation"
        sampled_requests_enabled   = true
      }
    }
  }

  # Rule 10: Size Restrictions
  dynamic "rule" {
    for_each = var.waf_rules.enable_size_restrictions ? [1] : []
    content {
      name     = "SizeRestrictionsRule"
      priority = 10

      override_action {
        none {}
      }

      statement {
        and_statement {
          statement {
            size_constraint_statement {
              field_to_match {
                body {}
              }
              comparison_operator = "GT"
              size                = 8192  # 8KB limit
              text_transformation {
                priority = 0
                type     = "NONE"
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.environment}-size-restrictions"
        sampled_requests_enabled   = true
      }

      action {
        block {}
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.environment}-web-acl"
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-web-acl"
    Purpose     = "waf-protection"
    Module      = "security"
  })
}

# =============================================================================
# WAF Logging Configuration
# =============================================================================

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count = var.enable_waf ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.main[0].arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs[0].arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  depends_on = [aws_cloudwatch_log_group.waf_logs]
}

resource "aws_cloudwatch_log_group" "waf_logs" {
  count = var.enable_waf ? 1 : 0

  name              = "/aws/wafv2/${var.project_name}-${var.environment}"
  retention_in_days = var.vpc_flow_logs_retention

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-waf-logs"
    Purpose     = "waf-logging"
    Module      = "security"
  })
}

# =============================================================================
# WAF Association with Resources
# =============================================================================

# Associate WAF with API Gateway (if provided)
resource "aws_wafv2_web_acl_association" "api_gateway" {
  count = var.enable_waf && var.api_gateway_id != "" && var.waf_scope == "REGIONAL" ? 1 : 0

  resource_arn = "arn:aws:apigateway:${data.aws_region.current.name}::/restapis/${var.api_gateway_id}/stages/*"
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn
}

# Associate WAF with Application Load Balancer (if provided)
resource "aws_wafv2_web_acl_association" "alb" {
  count = var.enable_waf && var.alb_arn != "" && var.waf_scope == "REGIONAL" ? 1 : 0

  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn
}

# Note: CloudFront association is handled differently and would be done in the CloudFront module

# =============================================================================
# CloudWatch Alarms for WAF
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  count = var.enable_waf && var.enable_security_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-waf-blocked-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "This metric monitors WAF blocked requests"
  alarm_actions       = var.enable_security_monitoring ? [aws_sns_topic.security_notifications[0].arn] : []

  dimensions = {
    WebACL = aws_wafv2_web_acl.main[0].name
    Region = data.aws_region.current.name
    Rule   = "ALL"
  }

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-waf-blocked-requests-alarm"
    Purpose     = "waf-monitoring"
    Module      = "security"
  })
}

resource "aws_cloudwatch_metric_alarm" "waf_rate_limit_triggered" {
  count = var.enable_waf && var.waf_rules.enable_rate_limiting && var.enable_security_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-waf-rate-limit"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors WAF rate limiting triggers"
  alarm_actions       = var.enable_security_monitoring ? [aws_sns_topic.security_notifications[0].arn] : []

  dimensions = {
    WebACL = aws_wafv2_web_acl.main[0].name
    Region = data.aws_region.current.name
    Rule   = "RateLimitingRule"
  }

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-waf-rate-limit-alarm"
    Purpose     = "waf-monitoring"
    Module      = "security"
  })
}

# =============================================================================
