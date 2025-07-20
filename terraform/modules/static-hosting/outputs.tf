# terraform/modules/static-hosting/outputs.tf

output "s3_bucket_name" {
  description = "Name of the S3 bucket for website content"
  value       = aws_s3_bucket.website.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for website content"
  value       = aws_s3_bucket.website.arn
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.website.bucket_domain_name
}

output "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.website.bucket_regional_domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website.id
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website.arn
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID for Route53 alias"
  value       = aws_cloudfront_distribution.website.hosted_zone_id
}

output "website_url" {
  description = "Website URL (CloudFront or custom domain)"
  value = var.enable_custom_domain ? (
    "https://${local.full_domain_name}"
  ) : (
    "https://${aws_cloudfront_distribution.website.domain_name}"
  )
}

output "origin_access_identity_iam_arn" {
  description = "IAM ARN of the CloudFront Origin Access Identity"
  value       = aws_cloudfront_origin_access_identity.website.iam_arn
}

output "ssl_certificate_arn" {
  description = "ARN of the SSL certificate (if custom domain enabled)"
  value       = var.enable_custom_domain ? aws_acm_certificate.website[0].arn : null
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID (if custom domain enabled)"
  value       = local.zone_id
}

output "logs_bucket_name" {
  description = "Name of the CloudFront logs S3 bucket"
  value       = var.enable_cloudfront_logging ? aws_s3_bucket.logs[0].bucket : null
}

output "deployment_info" {
  description = "Information for deployment scripts"
  value = {
    bucket_name            = aws_s3_bucket.website.bucket
    cloudfront_id          = aws_cloudfront_distribution.website.id
    website_url           = var.enable_custom_domain ? "https://${local.full_domain_name}" : "https://${aws_cloudfront_distribution.website.domain_name}"
    custom_domain_enabled = var.enable_custom_domain
    domain_name           = var.enable_custom_domain ? local.full_domain_name : null
  }
}
