# terraform/modules/static-hosting/acm.tf

# Data source for existing Route53 zone (if using custom domain)
data "aws_route53_zone" "main" {
  count = var.enable_custom_domain && !var.create_route53_zone ? 1 : 0
  name  = var.domain_name
}

# Create new Route53 hosted zone (optional)
resource "aws_route53_zone" "main" {
  count = var.enable_custom_domain && var.create_route53_zone ? 1 : 0
  name  = var.domain_name

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-zone"
    Environment = var.environment
  })
}

# Local value for the hosted zone
locals {
  zone_id = var.enable_custom_domain ? (
    var.create_route53_zone ? 
    aws_route53_zone.main[0].zone_id : 
    data.aws_route53_zone.main[0].zone_id
  ) : null
  
  full_domain_name = var.enable_custom_domain ? (
    var.subdomain != "" ? "${var.subdomain}.${var.domain_name}" : var.domain_name
  ) : null
}

# SSL Certificate from ACM (must be in us-east-1 for CloudFront)
resource "aws_acm_certificate" "website" {
  count           = var.enable_custom_domain ? 1 : 0
  domain_name     = local.full_domain_name
  validation_method = "DNS"

  # Optional: Add www subdomain
  subject_alternative_names = var.subdomain == "app" ? [
    "www.${var.domain_name}"
  ] : []

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-ssl-cert"
    Environment = var.environment
  })

  # Note: For CloudFront, certificate must be in us-east-1
  # In a real implementation, you would need to configure a provider alias
  # or use a separate module for ACM certificate creation
}

# Certificate validation DNS records
resource "aws_route53_record" "certificate_validation" {
  for_each = var.enable_custom_domain ? {
    for dvo in aws_acm_certificate.website[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = local.zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "website" {
  count           = var.enable_custom_domain ? 1 : 0
  certificate_arn = aws_acm_certificate.website[0].arn
  validation_record_fqdns = [
    for record in aws_route53_record.certificate_validation : record.fqdn
  ]

  timeouts {
    create = "5m"
  }

  # Note: For CloudFront, certificate validation must be in us-east-1
  # In a real implementation, you would need to configure a provider alias
}

# Route53 A record pointing to CloudFront
resource "aws_route53_record" "website" {
  count   = var.enable_custom_domain ? 1 : 0
  zone_id = local.zone_id
  name    = local.full_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

# Optional: Route53 AAAA record for IPv6
resource "aws_route53_record" "website_ipv6" {
  count   = var.enable_custom_domain ? 1 : 0
  zone_id = local.zone_id
  name    = local.full_domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}
