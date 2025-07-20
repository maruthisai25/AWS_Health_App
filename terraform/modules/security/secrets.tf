# =============================================================================
# AWS Secrets Manager Configuration
# =============================================================================

# =============================================================================
# Database Credentials Secret
# =============================================================================

resource "aws_secretsmanager_secret" "database_credentials" {
  count = var.enable_secrets_manager ? 1 : 0

  name                    = "${var.project_name}-${var.environment}-database-credentials"
  description             = "Database credentials for ${var.project_name} ${var.environment}"
  recovery_window_in_days = var.secrets_recovery_window
  kms_key_id             = var.create_additional_kms_keys ? aws_kms_key.secrets[0].arn : null

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-database-credentials"
    Purpose     = "database-secrets"
    Module      = "security"
  })
}

resource "aws_secretsmanager_secret_version" "database_credentials" {
  count = var.enable_secrets_manager ? 1 : 0

  secret_id = aws_secretsmanager_secret.database_credentials[0].id
  secret_string = jsonencode({
    username = "admin"
    password = "PLACEHOLDER_PASSWORD"  # This should be updated manually or via automation
    engine   = "postgres"
    host     = "PLACEHOLDER_HOST"
    port     = 5432
    dbname   = "education_platform"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# =============================================================================
# API Keys Secret
# =============================================================================

resource "aws_secretsmanager_secret" "api_keys" {
  count = var.enable_secrets_manager ? 1 : 0

  name                    = "${var.project_name}-${var.environment}-api-keys"
  description             = "API keys and tokens for ${var.project_name} ${var.environment}"
  recovery_window_in_days = var.secrets_recovery_window
  kms_key_id             = var.create_additional_kms_keys ? aws_kms_key.secrets[0].arn : null

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-api-keys"
    Purpose     = "api-secrets"
    Module      = "security"
  })
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  count = var.enable_secrets_manager ? 1 : 0

  secret_id = aws_secretsmanager_secret.api_keys[0].id
  secret_string = jsonencode({
    github_token     = "PLACEHOLDER_GITHUB_TOKEN"
    jwt_secret       = "PLACEHOLDER_JWT_SECRET"
    encryption_key   = "PLACEHOLDER_ENCRYPTION_KEY"
    webhook_secret   = "PLACEHOLDER_WEBHOOK_SECRET"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# =============================================================================
# Encryption Keys Secret
# =============================================================================

resource "aws_secretsmanager_secret" "encryption_keys" {
  count = var.enable_secrets_manager ? 1 : 0

  name                    = "${var.project_name}-${var.environment}-encryption-keys"
  description             = "Encryption keys for ${var.project_name} ${var.environment}"
  recovery_window_in_days = var.secrets_recovery_window
  kms_key_id             = var.create_additional_kms_keys ? aws_kms_key.secrets[0].arn : null

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-encryption-keys"
    Purpose     = "encryption-secrets"
    Module      = "security"
  })
}

resource "aws_secretsmanager_secret_version" "encryption_keys" {
  count = var.enable_secrets_manager ? 1 : 0

  secret_id = aws_secretsmanager_secret.encryption_keys[0].id
  secret_string = jsonencode({
    aes_key         = "PLACEHOLDER_AES_KEY"
    rsa_private_key = "PLACEHOLDER_RSA_PRIVATE_KEY"
    rsa_public_key  = "PLACEHOLDER_RSA_PUBLIC_KEY"
    salt            = "PLACEHOLDER_SALT"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# =============================================================================
# Third-Party Service Credentials
# =============================================================================

resource "aws_secretsmanager_secret" "third_party_credentials" {
  count = var.enable_secrets_manager ? 1 : 0

  name                    = "${var.project_name}-${var.environment}-third-party-credentials"
  description             = "Third-party service credentials for ${var.project_name} ${var.environment}"
  recovery_window_in_days = var.secrets_recovery_window
  kms_key_id             = var.create_additional_kms_keys ? aws_kms_key.secrets[0].arn : null

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-third-party-credentials"
    Purpose     = "third-party-secrets"
    Module      = "security"
  })
}

resource "aws_secretsmanager_secret_version" "third_party_credentials" {
  count = var.enable_secrets_manager ? 1 : 0

  secret_id = aws_secretsmanager_secret.third_party_credentials[0].id
  secret_string = jsonencode({
    smtp_username    = "PLACEHOLDER_SMTP_USERNAME"
    smtp_password    = "PLACEHOLDER_SMTP_PASSWORD"
    oauth_client_id  = "PLACEHOLDER_OAUTH_CLIENT_ID"
    oauth_secret     = "PLACEHOLDER_OAUTH_SECRET"
    analytics_key    = "PLACEHOLDER_ANALYTICS_KEY"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# =============================================================================
# Secrets Manager Resource Policies
# =============================================================================

resource "aws_secretsmanager_secret_policy" "database_credentials" {
  count = var.enable_secrets_manager ? 1 : 0

  secret_arn = aws_secretsmanager_secret.database_credentials[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowRDSAccess"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "secretsmanager:ResourceTag/Purpose" = "database-secrets"
          }
        }
      }
    ]
  })
}

# =============================================================================
# Automatic Secret Rotation (for supported services)
# =============================================================================

# Note: Automatic rotation would require Lambda functions and additional setup
# This is a placeholder for future implementation

resource "aws_secretsmanager_secret_rotation" "database_credentials" {
  count = var.enable_secrets_manager && var.environment != "dev" ? 1 : 0

  secret_id           = aws_secretsmanager_secret.database_credentials[0].id
  rotation_lambda_arn = "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:SecretsManagerRDSPostgreSQLRotationSingleUser"

  rotation_rules {
    automatically_after_days = 30
  }

  # This would require the AWS-provided rotation Lambda to be deployed
  # For now, this is commented out to avoid deployment issues
  # depends_on = [aws_lambda_function.rotation_lambda]
}

# =============================================================================
# Data Sources
# =============================================================================