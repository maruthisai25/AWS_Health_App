# =============================================================================
# AWS Education Platform - Video S3 Storage Configuration
# =============================================================================
#
# This file configures S3 buckets for video storage:
# - Raw video uploads bucket
# - Transcoded video storage bucket
# - Lifecycle policies for cost optimization
# - CORS configuration for uploads
# - Event notifications for processing
# =============================================================================

# =============================================================================
# Local Values for S3 Configuration
# =============================================================================

locals {
  raw_video_bucket_name = var.raw_video_bucket_name != "" ? var.raw_video_bucket_name : "${var.name_prefix}-raw-videos"
  transcoded_video_bucket_name = var.transcoded_video_bucket_name != "" ? var.transcoded_video_bucket_name : "${var.name_prefix}-transcoded-videos"
  
  # Common lifecycle rules
  lifecycle_rules = var.video_lifecycle_enabled ? [
    {
      id     = "raw_video_lifecycle"
      status = "Enabled"
      
      transition = [
        {
          days          = var.raw_video_retention_days
          storage_class = "STANDARD_IA"
        },
        {
          days          = var.raw_video_retention_days + 30
          storage_class = "GLACIER"
        }
      ]
    }
  ] : []
  
  # CORS rules for video uploads
  cors_rules = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
      allowed_origins = var.allowed_upload_origins
      expose_headers  = ["ETag", "x-amz-version-id"]
      max_age_seconds = 3000
    }
  ]
}

# =============================================================================
# S3 Bucket for Raw Video Uploads
# =============================================================================

resource "aws_s3_bucket" "raw_videos" {
  bucket = local.raw_video_bucket_name

  tags = merge(var.common_tags, var.video_bucket_tags, {
    Name        = local.raw_video_bucket_name
    Purpose     = "raw-video-storage"
    Module      = "video"
    Description = "Storage for raw video uploads before processing"
    ContentType = "video"
    Environment = var.environment
  })
}

# Versioning configuration for raw videos
resource "aws_s3_bucket_versioning" "raw_videos" {
  bucket = aws_s3_bucket.raw_videos.id
  
  versioning_configuration {
    status = var.enable_video_versioning ? "Enabled" : "Suspended"
  }
}

# Server-side encryption for raw videos
resource "aws_s3_bucket_server_side_encryption_configuration" "raw_videos" {
  count  = var.enable_bucket_encryption ? 1 : 0
  bucket = aws_s3_bucket.raw_videos.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Public access block for raw videos
resource "aws_s3_bucket_public_access_block" "raw_videos" {
  bucket = aws_s3_bucket.raw_videos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS configuration for raw videos
resource "aws_s3_bucket_cors_configuration" "raw_videos" {
  bucket = aws_s3_bucket.raw_videos.id

  dynamic "cors_rule" {
    for_each = local.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

# Lifecycle configuration for raw videos
resource "aws_s3_bucket_lifecycle_configuration" "raw_videos" {
  count  = var.video_lifecycle_enabled ? 1 : 0
  bucket = aws_s3_bucket.raw_videos.id
  
  rule {
    id     = "raw_video_lifecycle"
    status = "Enabled"

    # Move to Standard-IA after retention period
    transition {
      days          = var.raw_video_retention_days
      storage_class = "STANDARD_IA"
    }

    # Move to Glacier after extended period
    transition {
      days          = var.raw_video_retention_days + 60
      storage_class = "GLACIER"
    }

    # Additional cost optimization rules
    dynamic "transition" {
      for_each = var.enable_cost_optimization && var.cost_optimization_features.glacier_transition ? [1] : []
      content {
        days          = var.raw_video_retention_days + 180
        storage_class = "DEEP_ARCHIVE"
      }
    }

    # Delete incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Intelligent tiering rule
  dynamic "rule" {
    for_each = var.enable_cost_optimization && var.cost_optimization_features.intelligent_tiering ? [1] : []
    content {
      id     = "intelligent_tiering"
      status = "Enabled"

      transition {
        days          = 1
        storage_class = "INTELLIGENT_TIERING"
      }
    }
  }
}

# =============================================================================
# S3 Bucket for Transcoded Videos
# =============================================================================

resource "aws_s3_bucket" "transcoded_videos" {
  bucket = local.transcoded_video_bucket_name

  tags = merge(var.common_tags, var.video_bucket_tags, {
    Name        = local.transcoded_video_bucket_name
    Purpose     = "transcoded-video-storage"
    Module      = "video"
    Description = "Storage for processed and transcoded videos"
    ContentType = "video"
    Environment = var.environment
  })
}

# Versioning configuration for transcoded videos
resource "aws_s3_bucket_versioning" "transcoded_videos" {
  bucket = aws_s3_bucket.transcoded_videos.id
  
  versioning_configuration {
    status = var.enable_video_versioning ? "Enabled" : "Suspended"
  }
}

# Server-side encryption for transcoded videos
resource "aws_s3_bucket_server_side_encryption_configuration" "transcoded_videos" {
  count  = var.enable_bucket_encryption ? 1 : 0
  bucket = aws_s3_bucket.transcoded_videos.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Public access block for transcoded videos
resource "aws_s3_bucket_public_access_block" "transcoded_videos" {
  bucket = aws_s3_bucket.transcoded_videos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS configuration for transcoded videos
resource "aws_s3_bucket_cors_configuration" "transcoded_videos" {
  bucket = aws_s3_bucket.transcoded_videos.id

  dynamic "cors_rule" {
    for_each = local.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

# Lifecycle configuration for transcoded videos
resource "aws_s3_bucket_lifecycle_configuration" "transcoded_videos" {
  count  = var.video_lifecycle_enabled ? 1 : 0
  bucket = aws_s3_bucket.transcoded_videos.id
  
  rule {
    id     = "transcoded_video_lifecycle"
    status = "Enabled"

    # Move to Standard-IA after retention period
    transition {
      days          = var.transcoded_video_retention_days
      storage_class = "STANDARD_IA"
    }

    # Move to Glacier after extended period  
    transition {
      days          = var.transcoded_video_retention_days + 90
      storage_class = "GLACIER"
    }

    # Delete incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# =============================================================================
# S3 Transfer Acceleration (Optional)
# =============================================================================

resource "aws_s3_bucket_accelerate_configuration" "raw_videos" {
  count  = var.enable_transfer_acceleration ? 1 : 0
  bucket = aws_s3_bucket.raw_videos.id
  status = "Enabled"
}

# =============================================================================
# S3 Bucket Notifications for Video Processing
# =============================================================================

resource "aws_s3_bucket_notification" "raw_video_notifications" {
  bucket = aws_s3_bucket.raw_videos.id

  # Lambda function trigger for video processing
  lambda_function {
    lambda_function_arn = aws_lambda_function.video_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ""
  }

  # SNS notification for monitoring
  topic {
    topic_arn = aws_sns_topic.video_processing.arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  depends_on = [
    aws_lambda_permission.allow_s3_invoke,
    aws_sns_topic_policy.video_processing
  ]
}

# =============================================================================
# Bucket Policies for Access Control
# =============================================================================

# Policy for raw videos bucket
resource "aws_s3_bucket_policy" "raw_videos" {
  bucket = aws_s3_bucket.raw_videos.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.raw_videos.arn,
          "${aws_s3_bucket.raw_videos.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowTranscoderAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.transcoder_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.raw_videos.arn}/*"
      }
    ]
  })
}

# Policy for transcoded videos bucket
resource "aws_s3_bucket_policy" "transcoded_videos" {
  bucket = aws_s3_bucket.transcoded_videos.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.transcoded_videos.arn,
          "${aws_s3_bucket.transcoded_videos.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowTranscoderAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.transcoder_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.transcoded_videos.arn}/*"
      },
      {
        Sid    = "AllowCloudFrontAccess"
        Effect = "Allow"
        Principal = {
          AWS = try(aws_cloudfront_origin_access_identity.video_oai[0].iam_arn, "*")
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.transcoded_videos.arn}/*"
      }
    ]
  })
}