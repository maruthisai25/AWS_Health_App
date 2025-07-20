# =============================================================================
# AWS Education Platform - Video Module Outputs
# =============================================================================
#
# This file defines outputs for the video lecture system module.
# These outputs provide access to video infrastructure resources for:
# - Integration with other modules
# - Frontend application configuration
# - Monitoring and debugging
# =============================================================================

# =============================================================================
# S3 Bucket Outputs
# =============================================================================

output "raw_video_bucket_name" {
  description = "Name of the S3 bucket for raw video uploads"
  value       = aws_s3_bucket.raw_videos.bucket
}

output "raw_video_bucket_arn" {
  description = "ARN of the S3 bucket for raw video uploads"
  value       = aws_s3_bucket.raw_videos.arn
}

output "transcoded_video_bucket_name" {
  description = "Name of the S3 bucket for transcoded videos"
  value       = aws_s3_bucket.transcoded_videos.bucket
}

output "transcoded_video_bucket_arn" {
  description = "ARN of the S3 bucket for transcoded videos"
  value       = aws_s3_bucket.transcoded_videos.arn
}

output "video_bucket_domains" {
  description = "Domain names for video buckets"
  value = {
    raw_videos_domain        = aws_s3_bucket.raw_videos.bucket_domain_name
    transcoded_videos_domain = aws_s3_bucket.transcoded_videos.bucket_domain_name
  }
}

# =============================================================================
# Elastic Transcoder Outputs
# =============================================================================

output "transcoder_pipeline_id" {
  description = "ID of the Elastic Transcoder pipeline"
  value       = aws_elastictranscoder_pipeline.video_pipeline.id
}

output "transcoder_pipeline_arn" {
  description = "ARN of the Elastic Transcoder pipeline"
  value       = aws_elastictranscoder_pipeline.video_pipeline.arn
}

output "transcoder_presets" {
  description = "Map of transcoder preset IDs"
  value = {
    preset_1080p = try(aws_elastictranscoder_preset.preset_1080p[0].id, null)
    preset_720p  = try(aws_elastictranscoder_preset.preset_720p[0].id, null)
    preset_480p  = try(aws_elastictranscoder_preset.preset_480p[0].id, null)
    preset_hls   = try(aws_elastictranscoder_preset.preset_hls[0].id, null)
  }
}

output "transcoder_role_arn" {
  description = "ARN of the Elastic Transcoder service role"
  value       = aws_iam_role.transcoder_role.arn
}

# =============================================================================
# CloudFront Distribution Outputs
# =============================================================================

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution for video streaming"
  value       = try(aws_cloudfront_distribution.video_cdn[0].id, null)
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = try(aws_cloudfront_distribution.video_cdn[0].arn, null)
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = try(aws_cloudfront_distribution.video_cdn[0].domain_name, null)
}

output "video_streaming_url" {
  description = "Base URL for video streaming through CloudFront"
  value       = try("https://${aws_cloudfront_distribution.video_cdn[0].domain_name}", null)
}

output "cloudfront_distribution_status" {
  description = "Status of the CloudFront distribution"
  value       = try(aws_cloudfront_distribution.video_cdn[0].status, null)
}

# =============================================================================
# Lambda Function Outputs
# =============================================================================

output "video_processor_function_arn" {
  description = "ARN of the video processor Lambda function"
  value       = aws_lambda_function.video_processor.arn
}

output "video_processor_function_name" {
  description = "Name of the video processor Lambda function"
  value       = aws_lambda_function.video_processor.function_name
}

output "presigned_url_generator_arn" {
  description = "ARN of the presigned URL generator Lambda function"
  value       = aws_lambda_function.presigned_url_generator.arn
}

output "presigned_url_generator_name" {
  description = "Name of the presigned URL generator Lambda function"
  value       = aws_lambda_function.presigned_url_generator.function_name
}

output "lambda_security_group_id" {
  description = "ID of the security group for Lambda functions"
  value       = try(aws_security_group.lambda_sg[0].id, null)
}

# =============================================================================
# API Endpoints
# =============================================================================

output "video_upload_endpoint" {
  description = "API endpoint for video upload operations"
  value = {
    function_name = aws_lambda_function.presigned_url_generator.function_name
    description   = "Use this Lambda function to generate presigned URLs for video uploads"
  }
}

output "video_processing_endpoint" {
  description = "API endpoint for video processing operations"
  value = {
    function_name = aws_lambda_function.video_processor.function_name
    description   = "Automatically triggered when videos are uploaded to the raw videos bucket"
  }
}

# =============================================================================
# Security and IAM Outputs
# =============================================================================

output "video_processor_role_arn" {
  description = "ARN of the video processor Lambda execution role"
  value       = aws_iam_role.video_processor_role.arn
}

output "presigned_url_role_arn" {
  description = "ARN of the presigned URL generator Lambda execution role"
  value       = aws_iam_role.presigned_url_role.arn
}

output "video_access_policy_arn" {
  description = "ARN of the IAM policy for video access"
  value       = aws_iam_policy.video_access_policy.arn
}

# =============================================================================
# SNS and Notifications
# =============================================================================

output "video_processing_topic_arn" {
  description = "ARN of the SNS topic for video processing notifications"
  value       = aws_sns_topic.video_processing.arn
}

output "video_processing_topic_name" {
  description = "Name of the SNS topic for video processing notifications"
  value       = aws_sns_topic.video_processing.name
}

# =============================================================================
# CloudWatch and Monitoring
# =============================================================================

output "cloudwatch_log_groups" {
  description = "CloudWatch log groups for video module"
  value = {
    video_processor_logs      = aws_cloudwatch_log_group.video_processor_logs.name
    presigned_url_logs       = aws_cloudwatch_log_group.presigned_url_logs.name
    transcoder_logs          = aws_cloudwatch_log_group.transcoder_logs.name
  }
}

output "cloudwatch_metrics_namespace" {
  description = "CloudWatch metrics namespace for video module"
  value       = "EducationPlatform/Video"
}

# =============================================================================
# Configuration Information
# =============================================================================

output "video_module_config" {
  description = "Complete configuration information for the video module"
  value = {
    # Storage configuration
    storage = {
      raw_bucket        = aws_s3_bucket.raw_videos.bucket
      transcoded_bucket = aws_s3_bucket.transcoded_videos.bucket
      versioning_enabled = var.enable_video_versioning
    }
    
    # Processing configuration
    processing = {
      pipeline_id = aws_elastictranscoder_pipeline.video_pipeline.id
      presets_enabled = var.enable_transcoding_presets
      thumbnail_enabled = var.thumbnail_generation_enabled
    }
    
    # Streaming configuration
    streaming = {
      cdn_enabled = var.enable_video_cdn
      domain_name = try(aws_cloudfront_distribution.video_cdn[0].domain_name, null)
      signed_urls_enabled = var.enable_signed_urls
    }
    
    # Security configuration
    security = {
      encryption_enabled = var.enable_bucket_encryption
      kms_key_arn = var.kms_key_arn
      max_file_size_mb = var.max_video_size_mb
      allowed_formats = var.allowed_video_formats
    }
    
    # Lambda configuration
    lambda = {
      runtime = var.lambda_runtime
      memory_size = var.lambda_memory_size
      timeout = var.lambda_timeout
      vpc_enabled = var.enable_lambda_vpc
    }
  }
}

# =============================================================================
# Frontend Integration
# =============================================================================

output "frontend_config" {
  description = "Configuration values needed by the frontend application"
  value = {
    # Upload configuration
    upload = {
      presigned_url_function = aws_lambda_function.presigned_url_generator.function_name
      max_file_size_mb = var.max_video_size_mb
      allowed_formats = var.allowed_video_formats
      multipart_threshold_mb = var.multipart_threshold_mb
    }
    
    # Streaming configuration
    streaming = {
      base_url = try("https://${aws_cloudfront_distribution.video_cdn[0].domain_name}", null)
      signed_urls_enabled = var.enable_signed_urls
      cdn_enabled = var.enable_video_cdn
    }
    
    # Video quality options
    quality_options = {
      resolutions_available = [
        for preset, enabled in var.enable_transcoding_presets : preset if enabled
      ]
      default_quality = "720p"
    }
    
    # API endpoints
    api_endpoints = {
      upload_url_generator = aws_lambda_function.presigned_url_generator.function_name
      video_processor = aws_lambda_function.video_processor.function_name
    }
  }
}

# =============================================================================
# Debugging and Troubleshooting
# =============================================================================

output "debug_info" {
  description = "Debug information for troubleshooting"
  value = {
    module_version = "1.0.0"
    resources_created = {
      s3_buckets = 2
      lambda_functions = 2
      cloudfront_distribution = var.enable_video_cdn ? 1 : 0
      transcoder_pipeline = 1
      iam_roles = 3
      sns_topics = 1
      cloudwatch_log_groups = 3
    }
    feature_flags = {
      cdn_enabled = var.enable_video_cdn
      vpc_lambda = var.enable_lambda_vpc
      encryption_enabled = var.enable_bucket_encryption
      signed_urls_enabled = var.enable_signed_urls
      versioning_enabled = var.enable_video_versioning
      lifecycle_enabled = var.video_lifecycle_enabled
      cost_optimization = var.enable_cost_optimization
      analytics_enabled = var.enable_video_analytics
      thumbnail_generation = var.thumbnail_generation_enabled
    }
    environment_info = {
      name_prefix = var.name_prefix
      environment = var.environment
      project_name = var.project_name
      vpc_id = var.vpc_id
      private_subnets = var.private_subnets
    }
  }
}

# =============================================================================
# Resource ARNs for Cross-Module Integration
# =============================================================================

output "resource_arns" {
  description = "ARNs of all created resources for integration with other modules"
  value = {
    # S3 resources
    raw_video_bucket_arn = aws_s3_bucket.raw_videos.arn
    transcoded_video_bucket_arn = aws_s3_bucket.transcoded_videos.arn
    
    # Lambda resources
    video_processor_arn = aws_lambda_function.video_processor.arn
    presigned_url_generator_arn = aws_lambda_function.presigned_url_generator.arn
    
    # IAM resources
    video_processor_role_arn = aws_iam_role.video_processor_role.arn
    presigned_url_role_arn = aws_iam_role.presigned_url_role.arn
    transcoder_role_arn = aws_iam_role.transcoder_role.arn
    
    # CloudFront resources
    cloudfront_distribution_arn = try(aws_cloudfront_distribution.video_cdn[0].arn, null)
    
    # SNS resources
    video_processing_topic_arn = aws_sns_topic.video_processing.arn
    
    # Transcoder resources
    transcoder_pipeline_arn = aws_elastictranscoder_pipeline.video_pipeline.arn
  }
}