# =============================================================================
# CloudTrail Configuration
# =============================================================================

# Local values for CloudTrail
locals {
  cloudtrail_bucket_name = var.cloudtrail_s3_bucket_name != "" ? var.cloudtrail_s3_bucket_name : "${local.name_prefix}-cloudtrail-logs-${random_id.bucket_suffix.hex}"
}

# Random ID for unique bucket naming
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# =============================================================================
# S3 Bucket for CloudTrail Logs
# =============================================================================

resource "aws_s3_bucket" "cloudtrail_logs" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = local.cloudtrail_bucket_name

  tags = merge(var.tags, {
    Name        = local.cloudtrail_bucket_name
    Purpose     = "cloudtrail-logs"
    Module      = "monitoring"
  })
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_logs[0].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "cloudtrail_logs" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_logs[0].id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_logs" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_logs[0].id

  rule {
    id     = "cloudtrail_log_lifecycle"
    status = "Enabled"

    expiration {
      days = var.environment == "prod" ? 2555 : 90  # 7 years for prod, 90 days for dev
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# =============================================================================
# S3 Bucket Policy for CloudTrail
# =============================================================================

data "aws_iam_policy_document" "cloudtrail_s3_policy" {
  count = var.enable_cloudtrail ? 1 : 0

  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail_logs[0].arn]
    
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = ["arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${local.name_prefix}-cloudtrail"]
    }
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail_logs[0].arn}/*"]
    
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = ["arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/${local.name_prefix}-cloudtrail"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_logs[0].id
  policy = data.aws_iam_policy_document.cloudtrail_s3_policy[0].json
}

# =============================================================================
# CloudWatch Log Group for CloudTrail
# =============================================================================

resource "aws_cloudwatch_log_group" "cloudtrail" {
  count             = var.enable_cloudtrail ? 1 : 0
  name              = "/aws/cloudtrail/${local.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "/aws/cloudtrail/${local.name_prefix}"
    Purpose     = "cloudtrail-logs"
    Module      = "monitoring"
  })
}

# =============================================================================
# IAM Role for CloudTrail CloudWatch Logs
# =============================================================================

data "aws_iam_policy_document" "cloudtrail_assume_role" {
  count = var.enable_cloudtrail ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cloudtrail_cloudwatch_role" {
  count              = var.enable_cloudtrail ? 1 : 0
  name               = "${local.name_prefix}-cloudtrail-cloudwatch-role"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_assume_role[0].json

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-cloudtrail-cloudwatch-role"
    Purpose     = "cloudtrail-cloudwatch-logs"
    Module      = "monitoring"
  })
}

data "aws_iam_policy_document" "cloudtrail_cloudwatch_logs_policy" {
  count = var.enable_cloudtrail ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"]
  }
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch_logs_policy" {
  count  = var.enable_cloudtrail ? 1 : 0
  name   = "${local.name_prefix}-cloudtrail-cloudwatch-logs-policy"
  role   = aws_iam_role.cloudtrail_cloudwatch_role[0].id
  policy = data.aws_iam_policy_document.cloudtrail_cloudwatch_logs_policy[0].json
}

# =============================================================================
# CloudTrail
# =============================================================================

resource "aws_cloudtrail" "main" {
  count = var.enable_cloudtrail ? 1 : 0

  name           = "${local.name_prefix}-cloudtrail"
  s3_bucket_name = aws_s3_bucket.cloudtrail_logs[0].bucket

  # CloudWatch Logs integration
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail[0].arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch_role[0].arn

  # Configuration options
  include_global_service_events = var.cloudtrail_include_global_service_events
  is_multi_region_trail        = var.cloudtrail_is_multi_region_trail
  enable_log_file_validation   = var.enable_cloudtrail_log_file_validation

  # Event selectors for data events (optional)
  dynamic "event_selector" {
    for_each = var.enable_cloudtrail_data_events ? [1] : []
    content {
      read_write_type                 = "All"
      include_management_events       = true

      # S3 data events
      dynamic "data_resource" {
        for_each = length(var.s3_bucket_names) > 0 ? [1] : []
        content {
          type   = "AWS::S3::Object"
          values = [for bucket in var.s3_bucket_names : "${bucket}/*"]
        }
      }

      # Lambda data events
      dynamic "data_resource" {
        for_each = length(var.lambda_function_names) > 0 ? [1] : []
        content {
          type   = "AWS::Lambda::Function"
          values = [for func in var.lambda_function_names : "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:${func}"]
        }
      }
    }
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-cloudtrail"
    Purpose     = "audit-logging"
    Module      = "monitoring"
  })

  depends_on = [
    aws_s3_bucket_policy.cloudtrail_logs
  ]
}

# =============================================================================
# CloudWatch Alarms for CloudTrail
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "cloudtrail_errors" {
  count = var.enable_cloudtrail ? 1 : 0

  alarm_name          = "${local.name_prefix}-cloudtrail-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ErrorCount"
  namespace           = "CloudWatchLogs"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors CloudTrail errors"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    LogGroupName = aws_cloudwatch_log_group.cloudtrail[0].name
  }

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-cloudtrail-errors"
    Purpose     = "cloudtrail-error-monitoring"
    Module      = "monitoring"
  })
}

# =============================================================================
# CloudWatch Log Metric Filters for Security Events
# =============================================================================

# Root account usage
resource "aws_cloudwatch_log_metric_filter" "root_account_usage" {
  count          = var.enable_cloudtrail ? 1 : 0
  name           = "${local.name_prefix}-root-account-usage"
  log_group_name = aws_cloudwatch_log_group.cloudtrail[0].name
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"

  metric_transformation {
    name      = "RootAccountUsageCount"
    namespace = "${var.project_name}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_account_usage" {
  count = var.enable_cloudtrail ? 1 : 0

  alarm_name          = "${local.name_prefix}-root-account-usage"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "RootAccountUsageCount"
  namespace           = "${var.project_name}/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Root account usage detected"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-root-account-usage"
    Purpose     = "security-monitoring"
    Module      = "monitoring"
  })
}

# Unauthorized API calls
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  count          = var.enable_cloudtrail ? 1 : 0
  name           = "${local.name_prefix}-unauthorized-api-calls"
  log_group_name = aws_cloudwatch_log_group.cloudtrail[0].name
  pattern        = "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"

  metric_transformation {
    name      = "UnauthorizedApiCallsCount"
    namespace = "${var.project_name}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  count = var.enable_cloudtrail ? 1 : 0

  alarm_name          = "${local.name_prefix}-unauthorized-api-calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnauthorizedApiCallsCount"
  namespace           = "${var.project_name}/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Multiple unauthorized API calls detected"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-unauthorized-api-calls"
    Purpose     = "security-monitoring"
    Module      = "monitoring"
  })
}

# Console sign-in without MFA
resource "aws_cloudwatch_log_metric_filter" "console_signin_without_mfa" {
  count          = var.enable_cloudtrail ? 1 : 0
  name           = "${local.name_prefix}-console-signin-without-mfa"
  log_group_name = aws_cloudwatch_log_group.cloudtrail[0].name
  pattern        = "{ ($.eventName = \"ConsoleLogin\") && ($.additionalEventData.MFAUsed != \"Yes\") }"

  metric_transformation {
    name      = "ConsoleSigninWithoutMfaCount"
    namespace = "${var.project_name}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "console_signin_without_mfa" {
  count = var.enable_cloudtrail ? 1 : 0

  alarm_name          = "${local.name_prefix}-console-signin-without-mfa"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "ConsoleSigninWithoutMfaCount"
  namespace           = "${var.project_name}/Security"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Console sign-in without MFA detected"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  tags = merge(var.tags, {
    Name        = "${local.name_prefix}-console-signin-without-mfa"
    Purpose     = "security-monitoring"
    Module      = "monitoring"
  })
}