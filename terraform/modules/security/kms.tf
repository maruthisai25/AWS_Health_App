# =============================================================================
# KMS Keys for Encryption
# =============================================================================

# =============================================================================
# Database Encryption Key
# =============================================================================

resource "aws_kms_key" "database" {
  count = var.create_additional_kms_keys ? 1 : 0

  description             = "KMS key for database encryption in ${var.project_name} ${var.environment}"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = var.kms_key_rotation_enabled

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow RDS Service"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "rds.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-database-key"
    Purpose     = "database-encryption"
    Service     = "rds"
    Module      = "security"
  })
}

resource "aws_kms_alias" "database" {
  count = var.create_additional_kms_keys ? 1 : 0

  name          = "alias/${var.project_name}-${var.environment}-database"
  target_key_id = aws_kms_key.database[0].key_id
}

# =============================================================================
# S3 Encryption Key
# =============================================================================

resource "aws_kms_key" "s3" {
  count = var.create_additional_kms_keys ? 1 : 0

  description             = "KMS key for S3 encryption in ${var.project_name} ${var.environment}"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = var.kms_key_rotation_enabled

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      },
      {
        Sid    = "Allow CloudTrail"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-s3-key"
    Purpose     = "s3-encryption"
    Service     = "s3"
    Module      = "security"
  })
}

resource "aws_kms_alias" "s3" {
  count = var.create_additional_kms_keys ? 1 : 0

  name          = "alias/${var.project_name}-${var.environment}-s3"
  target_key_id = aws_kms_key.s3[0].key_id
}

# =============================================================================
# Lambda Encryption Key
# =============================================================================

resource "aws_kms_key" "lambda" {
  count = var.create_additional_kms_keys ? 1 : 0

  description             = "KMS key for Lambda encryption in ${var.project_name} ${var.environment}"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = var.kms_key_rotation_enabled

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda Service"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "lambda.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-lambda-key"
    Purpose     = "lambda-encryption"
    Service     = "lambda"
    Module      = "security"
  })
}

resource "aws_kms_alias" "lambda" {
  count = var.create_additional_kms_keys ? 1 : 0

  name          = "alias/${var.project_name}-${var.environment}-lambda"
  target_key_id = aws_kms_key.lambda[0].key_id
}

# =============================================================================
# Secrets Manager Encryption Key
# =============================================================================

resource "aws_kms_key" "secrets" {
  count = var.create_additional_kms_keys ? 1 : 0

  description             = "KMS key for Secrets Manager encryption in ${var.project_name} ${var.environment}"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = var.kms_key_rotation_enabled

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Secrets Manager Service"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-secrets-key"
    Purpose     = "secrets-encryption"
    Service     = "secretsmanager"
    Module      = "security"
  })
}

resource "aws_kms_alias" "secrets" {
  count = var.create_additional_kms_keys ? 1 : 0

  name          = "alias/${var.project_name}-${var.environment}-secrets"
  target_key_id = aws_kms_key.secrets[0].key_id
}

# =============================================================================
# CloudWatch Logs Encryption Key
# =============================================================================

resource "aws_kms_key" "cloudwatch" {
  count = var.create_additional_kms_keys ? 1 : 0

  description             = "KMS key for CloudWatch Logs encryption in ${var.project_name} ${var.environment}"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = var.kms_key_rotation_enabled

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-cloudwatch-key"
    Purpose     = "cloudwatch-encryption"
    Service     = "logs"
    Module      = "security"
  })
}

resource "aws_kms_alias" "cloudwatch" {
  count = var.create_additional_kms_keys ? 1 : 0

  name          = "alias/${var.project_name}-${var.environment}-cloudwatch"
  target_key_id = aws_kms_key.cloudwatch[0].key_id
}

# =============================================================================
# SNS Encryption Key
# =============================================================================

resource "aws_kms_key" "sns" {
  count = var.create_additional_kms_keys ? 1 : 0

  description             = "KMS key for SNS encryption in ${var.project_name} ${var.environment}"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = var.kms_key_rotation_enabled

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow SNS Service"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "sns.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-sns-key"
    Purpose     = "sns-encryption"
    Service     = "sns"
    Module      = "security"
  })
}

resource "aws_kms_alias" "sns" {
  count = var.create_additional_kms_keys ? 1 : 0

  name          = "alias/${var.project_name}-${var.environment}-sns"
  target_key_id = aws_kms_key.sns[0].key_id
}

# =============================================================================
# DynamoDB Encryption Key
# =============================================================================

resource "aws_kms_key" "dynamodb" {
  count = var.create_additional_kms_keys ? 1 : 0

  description             = "KMS key for DynamoDB encryption in ${var.project_name} ${var.environment}"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = var.kms_key_rotation_enabled

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow DynamoDB Service"
        Effect = "Allow"
        Principal = {
          Service = "dynamodb.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "dynamodb.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-dynamodb-key"
    Purpose     = "dynamodb-encryption"
    Service     = "dynamodb"
    Module      = "security"
  })
}

resource "aws_kms_alias" "dynamodb" {
  count = var.create_additional_kms_keys ? 1 : 0

  name          = "alias/${var.project_name}-${var.environment}-dynamodb"
  target_key_id = aws_kms_key.dynamodb[0].key_id
}

# =============================================================================
# Data Sources
# =============================================================================