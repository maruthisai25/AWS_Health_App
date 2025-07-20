# =============================================================================
# Lambda Functions for Video Processing Module
# =============================================================================

# Local values for consistent naming
locals {
  video_processor_name = "${var.name_prefix}-video-processor"
  presigned_url_name   = "${var.name_prefix}-presigned-url-generator"
  
  common_env_vars = {
    LOG_LEVEL               = "INFO"
    AWS_REGION             = data.aws_region.current.name
    TRANSCODER_PIPELINE_ID = aws_elastictranscoder_pipeline.video_pipeline.id
    RAW_BUCKET             = aws_s3_bucket.raw_videos.bucket
    TRANSCODED_BUCKET      = aws_s3_bucket.transcoded_videos.bucket
    SNS_TOPIC_ARN          = aws_sns_topic.video_processing.arn
  }
}

# =============================================================================
# Archive source code
# =============================================================================

data "archive_file" "video_processor" {
  type        = "zip"
  source_dir  = "${path.module}/../../../applications/lambda-functions/video-processor"
  output_path = "${path.module}/video-processor.zip"
}

# =============================================================================
# Lambda Function: Video Processor
# =============================================================================

resource "aws_lambda_function" "video_processor" {
  filename         = data.archive_file.video_processor.output_path
  function_name    = local.video_processor_name
  role            = aws_iam_role.video_processor_role.arn
  handler         = "index.handler"
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  source_code_hash = data.archive_file.video_processor.output_base64sha256

  # VPC configuration
  dynamic "vpc_config" {
    for_each = var.enable_lambda_vpc ? [1] : []
    content {
      subnet_ids         = var.private_subnets
      security_group_ids = [aws_security_group.lambda_sg[0].id]
    }
  }

  # Environment variables
  environment {
    variables = merge(local.common_env_vars, {
      FUNCTION_NAME = "video-processor"
      PRESETS = jsonencode({
        "1080p" = try(aws_elastictranscoder_preset.preset_1080p[0].id, "")
        "720p"  = try(aws_elastictranscoder_preset.preset_720p[0].id, "")
        "480p"  = try(aws_elastictranscoder_preset.preset_480p[0].id, "")
        "hls"   = try(aws_elastictranscoder_preset.preset_hls[0].id, "")
      })
    })
  }

  # Dead letter queue configuration
  dead_letter_config {
    target_arn = aws_sns_topic.video_processing.arn
  }

  tags = merge(var.common_tags, var.lambda_tags, {
    Name        = local.video_processor_name
    Purpose     = "video-processing"
    Module      = "video"
    Description = "Lambda function for processing uploaded videos"
  })

  depends_on = [
    aws_cloudwatch_log_group.video_processor_logs
  ]
}
# =============================================================================
# Lambda Function: Presigned URL Generator
# =============================================================================

# Archive source code
data "archive_file" "presigned_url_generator" {
  type        = "zip"
  source_dir  = "${path.module}/../../../applications/lambda-functions/presigned-url-generator"
  output_path = "${path.module}/presigned-url-generator.zip"
}

resource "aws_lambda_function" "presigned_url_generator" {
  filename         = data.archive_file.presigned_url_generator.output_path
  function_name    = local.presigned_url_name
  role            = aws_iam_role.presigned_url_role.arn
  handler         = "index.handler"
  runtime         = var.lambda_runtime
  timeout         = 30  # Shorter timeout for URL generation
  memory_size     = 256 # Less memory needed
  source_code_hash = data.archive_file.presigned_url_generator.output_base64sha256

  # VPC configuration
  dynamic "vpc_config" {
    for_each = var.enable_lambda_vpc ? [1] : []
    content {
      subnet_ids         = var.private_subnets
      security_group_ids = [aws_security_group.lambda_sg[0].id]
    }
  }

  # Environment variables
  environment {
    variables = merge(local.common_env_vars, {
      FUNCTION_NAME = "presigned-url-generator"
      URL_EXPIRATION_HOURS = tostring(var.signed_url_expiration_hours)
      MULTIPART_THRESHOLD_MB = tostring(var.multipart_threshold_mb)
      ENABLE_MULTIPART = tostring(var.enable_multipart_upload)
    })
  }
  
  tags = merge(var.common_tags, var.lambda_tags, {
    Name        = local.presigned_url_name
    Purpose     = "presigned-url-generation"
    Module      = "video"
    Description = "Lambda function for generating presigned URLs for video uploads"
  })

  depends_on = [
    aws_cloudwatch_log_group.presigned_url_logs
  ]
}

# =============================================================================
# Lambda Permissions
# =============================================================================

# Allow S3 to invoke video processor
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.video_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_videos.arn
}

# =============================================================================
# CloudWatch Log Groups
# =============================================================================

resource "aws_cloudwatch_log_group" "video_processor_logs" {
  name              = "/aws/lambda/${local.video_processor_name}"
  retention_in_days = var.cloudwatch_log_retention

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-video-processor-logs"
    Purpose     = "lambda-logging"
    Module      = "video"
    Description = "CloudWatch logs for video processor Lambda function"
  })
}

resource "aws_cloudwatch_log_group" "presigned_url_logs" {
  name              = "/aws/lambda/${local.presigned_url_name}"
  retention_in_days = var.cloudwatch_log_retention

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-presigned-url-logs"
    Purpose     = "lambda-logging"
    Module      = "video"
    Description = "CloudWatch logs for presigned URL generator Lambda function"
  })
}

# =============================================================================
# CloudWatch Alarms for Lambda Functions
# =============================================================================

# Video processor error alarm
resource "aws_cloudwatch_metric_alarm" "video_processor_errors" {
  count               = var.enable_cloudwatch_metrics ? 1 : 0
  alarm_name          = "${var.name_prefix}-video-processor-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors video processor lambda errors"
  alarm_actions       = [aws_sns_topic.video_processing.arn]

  dimensions = {
    FunctionName = aws_lambda_function.video_processor.function_name
  }

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-video-processor-errors"
    Purpose     = "monitoring"
    Module      = "video"
    Description = "CloudWatch alarm for video processor errors"
  })
}# Video processor duration alarm
resource "aws_cloudwatch_metric_alarm" "video_processor_duration" {
  count               = var.enable_cloudwatch_metrics ? 1 : 0
  alarm_name          = "${var.name_prefix}-video-processor-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "240000"  # 4 minutes in milliseconds
  alarm_description   = "This metric monitors video processor lambda duration"
  alarm_actions       = [aws_sns_topic.video_processing.arn]

  dimensions = {
    FunctionName = aws_lambda_function.video_processor.function_name
  }

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-video-processor-duration"
    Purpose     = "monitoring"
    Module      = "video"
    Description = "CloudWatch alarm for video processor duration"
  })
}

# Presigned URL generator error alarm
resource "aws_cloudwatch_metric_alarm" "presigned_url_errors" {
  count               = var.enable_cloudwatch_metrics ? 1 : 0
  alarm_name          = "${var.name_prefix}-presigned-url-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors presigned URL generator lambda errors"
  alarm_actions       = [aws_sns_topic.video_processing.arn]
  
  dimensions = {
    FunctionName = aws_lambda_function.presigned_url_generator.function_name
  }

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-presigned-url-errors"
    Purpose     = "monitoring"
    Module      = "video"
    Description = "CloudWatch alarm for presigned URL generator errors"
  })
}

# =============================================================================
# Security Group for Lambda Functions (if VPC is enabled)
# =============================================================================

resource "aws_security_group" "lambda_sg" {
  count = var.enable_lambda_vpc ? 1 : 0

  name_prefix = "${var.name_prefix}-video-lambda-"
  vpc_id      = var.vpc_id
  description = "Security group for video processing Lambda functions"

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for AWS API calls"
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound for external APIs"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-video-lambda-sg"
    Purpose     = "lambda-security"
    Module      = "video"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Data Sources
# =============================================================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}