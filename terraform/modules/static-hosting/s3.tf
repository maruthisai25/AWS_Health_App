# terraform/modules/static-hosting/s3.tf

# S3 bucket for static website hosting
resource "aws_s3_bucket" "website" {
  bucket        = "${var.project_name}-${var.environment}-website-${random_id.bucket_suffix.hex}"
  force_destroy = var.s3_force_destroy

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-website"
    Environment = var.environment
    Purpose     = "Static Website Hosting"
  })
}

# Random suffix for globally unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = var.s3_versioning_enabled ? "Enabled" : "Disabled"
  }
}

# S3 bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket public access block
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "website" {
  count  = var.s3_lifecycle_enabled ? 1 : 0
  bucket = aws_s3_bucket.website.id

  rule {
    id     = "lifecycle_rule"
    status = "Enabled"

    # Delete non-current versions after 30 days
    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    # Transition to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Transition to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Delete objects after 365 days in development
    dynamic "expiration" {
      for_each = var.environment == "dev" ? [1] : []
      content {
        days = 365
      }
    }
  }
}

# S3 bucket CORS configuration
resource "aws_s3_bucket_cors_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# S3 bucket policy for CloudFront OAI access
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.website.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}

# S3 bucket for CloudFront access logs (optional)
resource "aws_s3_bucket" "logs" {
  count         = var.enable_cloudfront_logging ? 1 : 0
  bucket        = "${var.project_name}-${var.environment}-cf-logs-${random_id.bucket_suffix.hex}"
  force_destroy = var.s3_force_destroy

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-cloudfront-logs"
    Environment = var.environment
    Purpose     = "CloudFront Access Logs"
  })
}

# CloudFront logs bucket public access block
resource "aws_s3_bucket_public_access_block" "logs" {
  count  = var.enable_cloudfront_logging ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
