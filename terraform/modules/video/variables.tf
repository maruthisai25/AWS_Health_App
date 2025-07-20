# =============================================================================
# AWS Education Platform - Video Module Variables
# =============================================================================
#
# This file defines all variables for the video lecture system module.
# This module handles video upload, processing, and streaming using:
# - S3 buckets for video storage
# - Elastic Transcoder for video processing
# - CloudFront for video delivery
# - Lambda for processing automation
# =============================================================================

# =============================================================================
# Basic Configuration
# =============================================================================

variable "name_prefix" {
  description = "Prefix for naming resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

# =============================================================================
# Networking Configuration
# =============================================================================

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs for Lambda functions"
  type        = list(string)
}

# =============================================================================
# Video Storage Configuration
# =============================================================================

variable "raw_video_bucket_name" {
  description = "Name for the raw video storage bucket (optional, will be auto-generated if not provided)"
  type        = string
  default     = ""
}

variable "transcoded_video_bucket_name" {
  description = "Name for the transcoded video storage bucket (optional, will be auto-generated if not provided)"
  type        = string
  default     = ""
}

variable "enable_video_versioning" {
  description = "Whether to enable versioning on video buckets"
  type        = bool
  default     = true
}

variable "video_lifecycle_enabled" {
  description = "Whether to enable lifecycle management for video files"
  type        = bool
  default     = true
}

variable "raw_video_retention_days" {
  description = "Number of days to retain raw video files before moving to cheaper storage"
  type        = number
  default     = 30
}

variable "transcoded_video_retention_days" {
  description = "Number of days to retain transcoded video files in standard storage"
  type        = number
  default     = 90
}

# =============================================================================
# Video Processing Configuration
# =============================================================================

variable "transcoding_pipeline_name" {
  description = "Name for the Elastic Transcoder pipeline"
  type        = string
  default     = ""
}

variable "enable_transcoding_presets" {
  description = "Map of transcoding presets to enable"
  type = object({
    enable_1080p = bool
    enable_720p  = bool
    enable_480p  = bool
    enable_hls   = bool
  })
  default = {
    enable_1080p = true
    enable_720p  = true
    enable_480p  = true
    enable_hls   = true
  }
}

variable "video_processing_timeout" {
  description = "Timeout for video processing Lambda function in seconds"
  type        = number
  default     = 300
}

variable "thumbnail_generation_enabled" {
  description = "Whether to generate thumbnails for videos"
  type        = bool
  default     = true
}

variable "thumbnail_intervals" {
  description = "List of time intervals (in seconds) for thumbnail generation"
  type        = list(number)
  default     = [10, 30, 60]  # Generate thumbnails at 10s, 30s, and 60s
}

# =============================================================================
# Video Streaming Configuration
# =============================================================================

variable "enable_video_cdn" {
  description = "Whether to enable CloudFront CDN for video streaming"
  type        = bool
  default     = true
}

variable "cloudfront_price_class" {
  description = "CloudFront price class for video delivery"
  type        = string
  default     = "PriceClass_100"
  
  validation {
    condition = contains([
      "PriceClass_All", 
      "PriceClass_200", 
      "PriceClass_100"
    ], var.cloudfront_price_class)
    error_message = "CloudFront price class must be PriceClass_All, PriceClass_200, or PriceClass_100."
  }
}

variable "video_cache_ttl" {
  description = "Cache TTL settings for video content"
  type = object({
    default_ttl = number
    max_ttl     = number
    min_ttl     = number
  })
  default = {
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
    min_ttl     = 0        # No minimum
  }
}

variable "enable_signed_urls" {
  description = "Whether to enable signed URLs for video access control"
  type        = bool
  default     = true
}

variable "signed_url_expiration_hours" {
  description = "Number of hours signed URLs remain valid"
  type        = number
  default     = 24
}

# =============================================================================
# Lambda Configuration
# =============================================================================

variable "lambda_runtime" {
  description = "Runtime for Lambda functions"
  type        = string
  default     = "nodejs18.x"
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda functions in MB"
  type        = number
  default     = 512
  
  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Lambda memory size must be between 128 and 10240 MB."
  }
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions in seconds"
  type        = number
  default     = 300
  
  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "enable_lambda_vpc" {
  description = "Whether to deploy Lambda functions in VPC"
  type        = bool
  default     = true
}

# =============================================================================
# Security Configuration
# =============================================================================

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "enable_bucket_encryption" {
  description = "Whether to enable S3 bucket encryption"
  type        = bool
  default     = true
}

variable "allowed_video_formats" {
  description = "List of allowed video file formats for upload"
  type        = list(string)
  default     = ["mp4", "mov", "avi", "mkv", "webm", "m4v"]
}

variable "max_video_size_mb" {
  description = "Maximum video file size in MB"
  type        = number
  default     = 5000  # 5GB
}

variable "allowed_upload_origins" {
  description = "List of allowed origins for video upload (CORS)"
  type        = list(string)
  default     = ["*"]  # Restrict this in production
}

# =============================================================================
# Video Quality and Compression Configuration
# =============================================================================

variable "video_quality_settings" {
  description = "Video quality settings for different resolutions"
  type = object({
    high_quality = object({
      resolution = string
      bitrate    = string
      preset     = string
    })
    medium_quality = object({
      resolution = string
      bitrate    = string
      preset     = string
    })
    low_quality = object({
      resolution = string
      bitrate    = string
      preset     = string
    })
  })
  default = {
    high_quality = {
      resolution = "1080p"
      bitrate    = "5000k"
      preset     = "web"
    }
    medium_quality = {
      resolution = "720p"
      bitrate    = "2500k"
      preset     = "web"
    }
    low_quality = {
      resolution = "480p"
      bitrate    = "1000k"
      preset     = "web"
    }
  }
}

# =============================================================================
# Monitoring and Logging Configuration
# =============================================================================

variable "enable_cloudwatch_metrics" {
  description = "Whether to enable detailed CloudWatch metrics"
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.cloudwatch_log_retention)
    error_message = "CloudWatch log retention must be a valid value."
  }
}

variable "enable_video_analytics" {
  description = "Whether to enable video viewing analytics"
  type        = bool
  default     = true
}

# =============================================================================
# Cost Optimization Configuration
# =============================================================================

variable "enable_cost_optimization" {
  description = "Whether to enable cost optimization features"
  type        = bool
  default     = false
}

variable "cost_optimization_features" {
  description = "Cost optimization features to enable"
  type = object({
    intelligent_tiering    = bool
    glacier_transition     = bool
    delete_incomplete_uploads = bool
    compress_videos        = bool
  })
  default = {
    intelligent_tiering      = false
    glacier_transition       = false
    delete_incomplete_uploads = true
    compress_videos          = true
  }
}

# =============================================================================
# Advanced Features Configuration
# =============================================================================

variable "enable_video_search" {
  description = "Whether to enable video content search capabilities"
  type        = bool
  default     = false
}

variable "enable_video_captions" {
  description = "Whether to enable automatic video caption generation"
  type        = bool
  default     = false
}

variable "enable_content_moderation" {
  description = "Whether to enable automatic content moderation for uploaded videos"
  type        = bool
  default     = false
}

variable "enable_video_watermarking" {
  description = "Whether to enable video watermarking"
  type        = bool
  default     = false
}

variable "watermark_image_url" {
  description = "URL of the watermark image (if watermarking is enabled)"
  type        = string
  default     = ""
}

# =============================================================================
# Performance Configuration
# =============================================================================

variable "enable_multipart_upload" {
  description = "Whether to enable multipart upload for large video files"
  type        = bool
  default     = true
}

variable "multipart_threshold_mb" {
  description = "Threshold in MB above which to use multipart upload"
  type        = number
  default     = 100
}

variable "concurrent_upload_parts" {
  description = "Number of concurrent parts for multipart upload"
  type        = number
  default     = 3
}

variable "enable_transfer_acceleration" {
  description = "Whether to enable S3 Transfer Acceleration for uploads"
  type        = bool
  default     = false  # Additional cost, enable for production
}

# =============================================================================
# Tags Configuration
# =============================================================================

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default     = {}
}

variable "video_bucket_tags" {
  description = "Additional tags for video storage buckets"
  type        = map(string)
  default     = {}
}

variable "lambda_tags" {
  description = "Additional tags for Lambda functions"
  type        = map(string)
  default     = {}
}

variable "cloudfront_tags" {
  description = "Additional tags for CloudFront distribution"
  type        = map(string)
  default     = {}
}