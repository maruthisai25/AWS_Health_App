# =============================================================================
# AWS Education Platform - Elastic Transcoder Configuration
# =============================================================================
#
# This file configures AWS Elastic Transcoder for video processing:
# - Transcoding pipeline
# - Custom presets for different video qualities
# - IAM roles and permissions
# - Integration with S3 buckets
# =============================================================================

# =============================================================================
# Local Values for Transcoder Configuration
# =============================================================================

locals {
  pipeline_name = var.transcoding_pipeline_name != "" ? var.transcoding_pipeline_name : "${var.name_prefix}-video-pipeline"
  
  # Transcoding preset configurations
  preset_configs = {
    "1080p" = {
      name        = "${var.name_prefix}-preset-1080p"
      description = "High quality 1080p preset"
      container   = "mp4"
      video = {
        codec                = "H.264"
        codec_options = {
          Profile = "main"
          Level   = "4.1"
        }
        keyframes_max_dist = "240"
        fixed_gop         = "false"
        bit_rate          = "5000"
        frame_rate        = "auto"
        max_width         = "1920"
        max_height        = "1080"
        display_aspect_ratio = "auto"
        sizing_policy     = "Fit"
        padding_policy    = "NoPad"
      }
      audio = {
        codec        = "AAC"
        sample_rate  = "44100"
        bit_rate     = "128"
        channels     = "2"
      }
    }
    
    "720p" = {
      name        = "${var.name_prefix}-preset-720p"
      description = "Medium quality 720p preset"
      container   = "mp4"
      video = {
        codec                = "H.264"
        codec_options = {
          Profile = "main"
          Level   = "3.1"
        }
        keyframes_max_dist = "240"
        fixed_gop         = "false"
        bit_rate          = "2500"
        frame_rate        = "auto"
        max_width         = "1280"
        max_height        = "720"
        display_aspect_ratio = "auto"
        sizing_policy     = "Fit"
        padding_policy    = "NoPad"
      }
      audio = {
        codec        = "AAC"
        sample_rate  = "44100"
        bit_rate     = "128"
        channels     = "2"
      }
    }
    
    "480p" = {
      name        = "${var.name_prefix}-preset-480p"
      description = "Low quality 480p preset"
      container   = "mp4"
      video = {
        codec                = "H.264"
        codec_options = {
          Profile = "baseline"
          Level   = "3.0"
        }
        keyframes_max_dist = "240"
        fixed_gop         = "false"
        bit_rate          = "1000"
        frame_rate        = "auto"
        max_width         = "854"
        max_height        = "480"
        display_aspect_ratio = "auto"
        sizing_policy     = "Fit"
        padding_policy    = "NoPad"
      }
      audio = {
        codec        = "AAC"
        sample_rate  = "44100"
        bit_rate     = "96"
        channels     = "2"
      }
    }
  }
}

# =============================================================================
# IAM Role for Elastic Transcoder
# =============================================================================

resource "aws_iam_role" "transcoder_role" {
  name = "${var.name_prefix}-transcoder-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "elastictranscoder.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-transcoder-role"
    Purpose     = "elastic-transcoder-execution"
    Module      = "video"
    Description = "IAM role for Elastic Transcoder pipeline"
  })
}

# IAM policy for Elastic Transcoder
resource "aws_iam_role_policy" "transcoder_policy" {
  name = "${var.name_prefix}-transcoder-policy"
  role = aws_iam_role.transcoder_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.raw_videos.arn}/*",
          "${aws_s3_bucket.transcoded_videos.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.raw_videos.arn,
          aws_s3_bucket.transcoded_videos.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.video_processing.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:ReEncrypt*"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# =============================================================================
# Elastic Transcoder Pipeline
# =============================================================================

resource "aws_elastictranscoder_pipeline" "video_pipeline" {
  input_bucket = aws_s3_bucket.raw_videos.bucket
  name         = local.pipeline_name
  role         = aws_iam_role.transcoder_role.arn

  content_config {
    bucket        = aws_s3_bucket.transcoded_videos.bucket
    storage_class = "Standard"
  }

  thumbnail_config {
    bucket        = aws_s3_bucket.transcoded_videos.bucket
    storage_class = "Standard"
  }

  # Optional: SNS notifications
  notifications {
    completed   = aws_sns_topic.video_processing.arn
    error       = aws_sns_topic.video_processing.arn
    progressing = aws_sns_topic.video_processing.arn
    warning     = aws_sns_topic.video_processing.arn
  }
}

# =============================================================================
# Custom Transcoding Presets
# =============================================================================

# 1080p Preset
resource "aws_elastictranscoder_preset" "preset_1080p" {
  count       = var.enable_transcoding_presets.enable_1080p ? 1 : 0
  container   = local.preset_configs["1080p"].container
  description = local.preset_configs["1080p"].description
  name        = local.preset_configs["1080p"].name

  audio {
    audio_packing_mode = "SingleTrack"
    bit_rate           = local.preset_configs["1080p"].audio.bit_rate
    channels           = local.preset_configs["1080p"].audio.channels
    codec              = local.preset_configs["1080p"].audio.codec
    sample_rate        = local.preset_configs["1080p"].audio.sample_rate
  }

  video {
    bit_rate               = local.preset_configs["1080p"].video.bit_rate
    codec                  = local.preset_configs["1080p"].video.codec
    display_aspect_ratio   = local.preset_configs["1080p"].video.display_aspect_ratio
    fixed_gop              = local.preset_configs["1080p"].video.fixed_gop
    frame_rate             = local.preset_configs["1080p"].video.frame_rate
    keyframes_max_dist     = local.preset_configs["1080p"].video.keyframes_max_dist
    max_height             = local.preset_configs["1080p"].video.max_height
    max_width              = local.preset_configs["1080p"].video.max_width
    padding_policy         = local.preset_configs["1080p"].video.padding_policy
    sizing_policy          = local.preset_configs["1080p"].video.sizing_policy
  }

  # Thumbnails configuration
  dynamic "thumbnails" {
    for_each = var.thumbnail_generation_enabled ? [1] : []
    content {
      format         = "png"
      interval       = "300"  # Every 5 minutes
      max_width      = "320"
      max_height     = "240"
      padding_policy = "NoPad"
      sizing_policy  = "Fit"
    }
  }
}

# 720p Preset
resource "aws_elastictranscoder_preset" "preset_720p" {
  count       = var.enable_transcoding_presets.enable_720p ? 1 : 0
  container   = local.preset_configs["720p"].container
  description = local.preset_configs["720p"].description
  name        = local.preset_configs["720p"].name

  audio {
    audio_packing_mode = "SingleTrack"
    bit_rate           = local.preset_configs["720p"].audio.bit_rate
    channels           = local.preset_configs["720p"].audio.channels
    codec              = local.preset_configs["720p"].audio.codec
    sample_rate        = local.preset_configs["720p"].audio.sample_rate
  }

  video {
    bit_rate               = local.preset_configs["720p"].video.bit_rate
    codec                  = local.preset_configs["720p"].video.codec
    display_aspect_ratio   = local.preset_configs["720p"].video.display_aspect_ratio
    fixed_gop              = local.preset_configs["720p"].video.fixed_gop
    frame_rate             = local.preset_configs["720p"].video.frame_rate
    keyframes_max_dist     = local.preset_configs["720p"].video.keyframes_max_dist
    max_height             = local.preset_configs["720p"].video.max_height
    max_width              = local.preset_configs["720p"].video.max_width
    padding_policy         = local.preset_configs["720p"].video.padding_policy
    sizing_policy          = local.preset_configs["720p"].video.sizing_policy
  }

  dynamic "thumbnails" {
    for_each = var.thumbnail_generation_enabled ? [1] : []
    content {
      format         = "png"
      interval       = "300"
      max_width      = "320"
      max_height     = "240"
      padding_policy = "NoPad"
      sizing_policy  = "Fit"
    }
  }
}

# 480p Preset
resource "aws_elastictranscoder_preset" "preset_480p" {
  count       = var.enable_transcoding_presets.enable_480p ? 1 : 0
  container   = local.preset_configs["480p"].container
  description = local.preset_configs["480p"].description
  name        = local.preset_configs["480p"].name

  audio {
    audio_packing_mode = "SingleTrack"
    bit_rate           = local.preset_configs["480p"].audio.bit_rate
    channels           = local.preset_configs["480p"].audio.channels
    codec              = local.preset_configs["480p"].audio.codec
    sample_rate        = local.preset_configs["480p"].audio.sample_rate
  }

  video {
    bit_rate               = local.preset_configs["480p"].video.bit_rate
    codec                  = local.preset_configs["480p"].video.codec
    display_aspect_ratio   = local.preset_configs["480p"].video.display_aspect_ratio
    fixed_gop              = local.preset_configs["480p"].video.fixed_gop
    frame_rate             = local.preset_configs["480p"].video.frame_rate
    keyframes_max_dist     = local.preset_configs["480p"].video.keyframes_max_dist
    max_height             = local.preset_configs["480p"].video.max_height
    max_width              = local.preset_configs["480p"].video.max_width
    padding_policy         = local.preset_configs["480p"].video.padding_policy
    sizing_policy          = local.preset_configs["480p"].video.sizing_policy
  }

  dynamic "thumbnails" {
    for_each = var.thumbnail_generation_enabled ? [1] : []
    content {
      format         = "png"
      interval       = "300"
      max_width      = "320"
      max_height     = "240"
      padding_policy = "NoPad"
      sizing_policy  = "Fit"
    }
  }
}

# HLS Preset for Adaptive Streaming
resource "aws_elastictranscoder_preset" "preset_hls" {
  count       = var.enable_transcoding_presets.enable_hls ? 1 : 0
  container   = "ts"
  description = "${var.name_prefix} HLS streaming preset"
  name        = "${var.name_prefix}-preset-hls"

  audio {
    audio_packing_mode = "SingleTrack"
    bit_rate           = "128"
    channels           = "2"
    codec              = "AAC"
    sample_rate        = "44100"
  }

  video {
    bit_rate               = "2500"
    codec                  = "H.264"
    display_aspect_ratio   = "auto"
    fixed_gop              = "false"
    frame_rate             = "auto"
    keyframes_max_dist     = "240"
    max_height             = "720"
    max_width              = "1280"
    padding_policy         = "NoPad"
    sizing_policy          = "Fit"
  }

  dynamic "thumbnails" {
    for_each = var.thumbnail_generation_enabled ? [1] : []
    content {
      format         = "png"
      interval       = "300"
      max_width      = "320"
      max_height     = "240"
      padding_policy = "NoPad"
      sizing_policy  = "Fit"
    }
  }
}

# =============================================================================
# SNS Topic for Video Processing Notifications
# =============================================================================

resource "aws_sns_topic" "video_processing" {
  name = "${var.name_prefix}-video-processing"

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-video-processing"
    Purpose     = "video-processing-notifications"
    Module      = "video"
    Description = "SNS topic for video processing status notifications"
  })
}

# SNS topic policy for Elastic Transcoder
resource "aws_sns_topic_policy" "video_processing" {
  arn = aws_sns_topic.video_processing.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowTranscoderPublish"
        Effect = "Allow"
        Principal = {
          Service = "elastictranscoder.amazonaws.com"
        }
        Action = "sns:Publish"
        Resource = aws_sns_topic.video_processing.arn
      },
      {
        Sid    = "AllowS3Publish"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "sns:Publish"
        Resource = aws_sns_topic.video_processing.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# =============================================================================
# CloudWatch Log Group for Transcoder Logs
# =============================================================================

resource "aws_cloudwatch_log_group" "transcoder_logs" {
  name              = "/aws/elastictranscoder/${var.name_prefix}"
  retention_in_days = var.cloudwatch_log_retention

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-transcoder-logs"
    Purpose     = "video-transcoding-logs"
    Module      = "video"
    Description = "CloudWatch logs for Elastic Transcoder pipeline"
  })
}

# =============================================================================
# Data Source for Current AWS Account
# =============================================================================