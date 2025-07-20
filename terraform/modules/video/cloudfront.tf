# =============================================================================
# AWS Education Platform - CloudFront Video CDN Configuration
# =============================================================================
#
# This file configures CloudFront for video streaming:
# - Origin Access Identity for S3 access
# - Distribution with optimized video caching
# - Custom behaviors for different content types
# - Signed URLs for access control
# =============================================================================

# =============================================================================
# Local Values for CloudFront Configuration
# =============================================================================

locals {
  # CloudFront distribution comment
  distribution_comment = "CloudFront distribution for ${var.project_name} ${var.environment} video streaming"
  
  # Origin domain name for transcoded videos
  origin_domain_name = aws_s3_bucket.transcoded_videos.bucket_domain_name
  
  # Default cache behaviors
  default_cache_behavior = {
    allowed_methods         = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.transcoded_videos.bucket}"
    compress               = true
    query_string           = false
    query_string_cache_keys = []
    cookies_forward        = "none"
    headers                = []
    viewer_protocol_policy = "redirect-to-https"
    
    # Cache TTL settings for videos
    min_ttl     = var.video_cache_ttl.min_ttl
    default_ttl = var.video_cache_ttl.default_ttl
    max_ttl     = var.video_cache_ttl.max_ttl
  }
  
  # Custom behaviors for different file types
  ordered_cache_behaviors = [
    # HLS playlist files - short cache
    {
      path_pattern           = "*.m3u8"
      target_origin_id       = "S3-${aws_s3_bucket.transcoded_videos.bucket}"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      compress               = true
      query_string           = false
      cookies_forward        = "none"
      headers                = []
      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 5      # 5 seconds for playlists
      max_ttl                = 300    # 5 minutes max
    },
    # Video segments - longer cache
    {
      path_pattern           = "*.ts"
      target_origin_id       = "S3-${aws_s3_bucket.transcoded_videos.bucket}"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      compress               = false  # Video segments shouldn't be compressed
      query_string           = false
      cookies_forward        = "none"
      headers                = []
      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 86400   # 1 day for segments
      max_ttl                = 31536000 # 1 year max
    },
    # Thumbnail images
    {
      path_pattern           = "thumbnails/*"
      target_origin_id       = "S3-${aws_s3_bucket.transcoded_videos.bucket}"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      compress               = true
      query_string           = false
      cookies_forward        = "none"
      headers                = []
      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 86400   # 1 day for thumbnails
      max_ttl                = 31536000 # 1 year max
    }
  ]
}

# =============================================================================
# CloudFront Origin Access Identity
# =============================================================================

resource "aws_cloudfront_origin_access_identity" "video_oai" {
  count   = var.enable_video_cdn ? 1 : 0
  comment = "OAI for ${var.name_prefix} video streaming"
}

# =============================================================================
# CloudFront Distribution for Video Streaming
# =============================================================================

resource "aws_cloudfront_distribution" "video_cdn" {
  count   = var.enable_video_cdn ? 1 : 0
  comment = local.distribution_comment
  enabled = true

  # Origin configuration
  origin {
    domain_name = local.origin_domain_name
    origin_id   = "S3-${aws_s3_bucket.transcoded_videos.bucket}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.video_oai[0].cloudfront_access_identity_path
    }

    # Custom headers for origin requests
    custom_header {
      name  = "X-Video-Module"
      value = var.name_prefix
    }
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods          = local.default_cache_behavior.allowed_methods
    cached_methods           = local.default_cache_behavior.cached_methods
    target_origin_id         = local.default_cache_behavior.target_origin_id
    compress                 = local.default_cache_behavior.compress
    viewer_protocol_policy   = local.default_cache_behavior.viewer_protocol_policy

    min_ttl     = local.default_cache_behavior.min_ttl
    default_ttl = local.default_cache_behavior.default_ttl
    max_ttl     = local.default_cache_behavior.max_ttl

    forwarded_values {
      query_string = local.default_cache_behavior.query_string
      headers      = local.default_cache_behavior.headers

      cookies {
        forward = local.default_cache_behavior.cookies_forward
      }
    }

    # Trusted signers for signed URLs
    dynamic "trusted_signers" {
      for_each = var.enable_signed_urls ? [1] : []
      content {
        enabled   = true
        items     = [data.aws_caller_identity.current.account_id]
      }
    }
  }

  # Ordered cache behaviors for specific content types
  dynamic "ordered_cache_behavior" {
    for_each = local.ordered_cache_behaviors
    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      target_origin_id       = ordered_cache_behavior.value.target_origin_id
      allowed_methods        = ordered_cache_behavior.value.allowed_methods
      cached_methods         = ordered_cache_behavior.value.cached_methods
      compress               = ordered_cache_behavior.value.compress
      viewer_protocol_policy = ordered_cache_behavior.value.viewer_protocol_policy

      min_ttl     = ordered_cache_behavior.value.min_ttl
      default_ttl = ordered_cache_behavior.value.default_ttl
      max_ttl     = ordered_cache_behavior.value.max_ttl

      forwarded_values {
        query_string = ordered_cache_behavior.value.query_string
        headers      = ordered_cache_behavior.value.headers

        cookies {
          forward = ordered_cache_behavior.value.cookies_forward
        }
      }

      # Trusted signers for signed URLs
      dynamic "trusted_signers" {
        for_each = var.enable_signed_urls ? [1] : []
        content {
          enabled   = true
          items     = [data.aws_caller_identity.current.account_id]
        }
      }
    }
  }

  # Geographic restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # SSL/TLS certificate configuration
  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  # Price class for cost optimization
  price_class = var.cloudfront_price_class

  # Custom error pages
  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/error.html"
    error_caching_min_ttl = 300
  }

  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/error.html"
    error_caching_min_ttl = 300
  }

  # Logging configuration
  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cloudfront_logs[0].bucket_domain_name
    prefix          = "video-cdn-logs/"
  }

  # Wait for deployment
  wait_for_deployment = false

  tags = merge(var.common_tags, var.cloudfront_tags, {
    Name        = "${var.name_prefix}-video-cdn"
    Purpose     = "video-streaming"
    Module      = "video"
    Description = "CloudFront distribution for video content delivery"
  })

  depends_on = [
    aws_s3_bucket_policy.transcoded_videos
  ]
}

# =============================================================================
# S3 Bucket for CloudFront Access Logs
# =============================================================================

resource "aws_s3_bucket" "cloudfront_logs" {
  count  = var.enable_video_cdn ? 1 : 0
  bucket = "${var.name_prefix}-cloudfront-logs"

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-cloudfront-logs"
    Purpose     = "cloudfront-access-logs"
    Module      = "video"
    Description = "S3 bucket for CloudFront access logs"
  })
}

# Public access block for CloudFront logs bucket
resource "aws_s3_bucket_public_access_block" "cloudfront_logs" {
  count  = var.enable_video_cdn ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for CloudFront logs
resource "aws_s3_bucket_lifecycle_configuration" "cloudfront_logs" {
  count  = var.enable_video_cdn ? 1 : 0
  bucket = aws_s3_bucket.cloudfront_logs[0].id

  rule {
    id     = "cloudfront_logs_lifecycle"
    status = "Enabled"

    # Delete logs after 90 days
    expiration {
      days = 90
    }

    # Delete incomplete multipart uploads after 7 days
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# =============================================================================
# CloudFront Function for Request/Response Manipulation (Optional)
# =============================================================================

resource "aws_cloudfront_function" "video_security" {
  count   = var.enable_video_cdn && var.enable_signed_urls ? 1 : 0
  name    = "${var.name_prefix}-video-security"
  runtime = "cloudfront-js-1.0"
  comment = "Security headers and validation for video requests"
  publish = true

  code = <<-EOT
function handler(event) {
    var request = event.request;
    var headers = request.headers;

    // Add security headers
    var response = {
        statusCode: 200,
        statusDescription: 'OK',
        headers: {
            'x-frame-options': { value: 'DENY' },
            'x-content-type-options': { value: 'nosniff' },
            'x-xss-protection': { value: '1; mode=block' },
            'strict-transport-security': { value: 'max-age=31536000; includeSubDomains' },
            'cache-control': { value: 'public, max-age=86400' }
        }
    };

    // Log request for analytics
    console.log('Video request:', JSON.stringify({
        uri: request.uri,
        method: request.method,
        headers: headers,
        timestamp: new Date().toISOString()
    }));

    return request;
}
EOT
}

# =============================================================================
# CloudWatch Metrics for Video CDN
# =============================================================================

resource "aws_cloudwatch_dashboard" "video_cdn_dashboard" {
  count          = var.enable_video_cdn && var.enable_cloudwatch_metrics ? 1 : 0
  dashboard_name = "${var.name_prefix}-video-cdn"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", aws_cloudfront_distribution.video_cdn[0].id],
            [".", "BytesDownloaded", ".", "."],
            [".", "BytesUploaded", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"  # CloudFront metrics are always in us-east-1
          title   = "Video CDN Traffic"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/CloudFront", "CacheHitRate", "DistributionId", aws_cloudfront_distribution.video_cdn[0].id],
            [".", "OriginLatency", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Video CDN Performance"
          period  = 300
        }
      }
    ]
  })
}

# =============================================================================
# Data Source for Current AWS Account
# =============================================================================