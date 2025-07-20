# =============================================================================
# IAM Security Configuration
# =============================================================================

# =============================================================================
# IAM Password Policy
# =============================================================================

resource "aws_iam_account_password_policy" "main" {
  count = var.enable_password_policy ? 1 : 0

  minimum_password_length        = var.password_policy.minimum_password_length
  require_lowercase_characters   = var.password_policy.require_lowercase_characters
  require_uppercase_characters   = var.password_policy.require_uppercase_characters
  require_numbers               = var.password_policy.require_numbers
  require_symbols               = var.password_policy.require_symbols
  allow_users_to_change_password = var.password_policy.allow_users_to_change_password
  max_password_age              = var.password_policy.max_password_age
  password_reuse_prevention     = var.password_policy.password_reuse_prevention
}

# =============================================================================
# IAM Access Analyzer
# =============================================================================

resource "aws_accessanalyzer_analyzer" "main" {
  count = var.enable_iam_access_analyzer ? 1 : 0

  analyzer_name = "${var.project_name}-${var.environment}-access-analyzer"
  type         = "ACCOUNT"

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-access-analyzer"
    Purpose     = "iam-analysis"
    Module      = "security"
  })
}

# =============================================================================
# Security IAM Roles
# =============================================================================

# Security Administrator Role
resource "aws_iam_role" "security_admin" {
  count = var.create_security_roles ? 1 : 0

  name = "${var.project_name}-${var.environment}-security-admin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-security-admin"
    Purpose     = "security-administration"
    Module      = "security"
  })
}

resource "aws_iam_role_policy" "security_admin" {
  count = var.create_security_roles ? 1 : 0

  name = "${var.project_name}-${var.environment}-security-admin-policy"
  role = aws_iam_role.security_admin[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "wafv2:*",
          "guardduty:*",
          "securityhub:*",
          "config:*",
          "cloudtrail:*",
          "iam:Get*",
          "iam:List*",
          "iam:GenerateCredentialReport",
          "iam:GenerateServiceLastAccessedDetails",
          "kms:*",
          "secretsmanager:*",
          "access-analyzer:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/security/*"
      }
    ]
  })
}

# Security Auditor Role (Read-only)
resource "aws_iam_role" "security_auditor" {
  count = var.create_security_roles ? 1 : 0

  name = "${var.project_name}-${var.environment}-security-auditor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-security-auditor"
    Purpose     = "security-auditing"
    Module      = "security"
  })
}

resource "aws_iam_role_policy" "security_auditor" {
  count = var.create_security_roles ? 1 : 0

  name = "${var.project_name}-${var.environment}-security-auditor-policy"
  role = aws_iam_role.security_auditor[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "wafv2:Get*",
          "wafv2:List*",
          "wafv2:Describe*",
          "guardduty:Get*",
          "guardduty:List*",
          "guardduty:Describe*",
          "securityhub:Get*",
          "securityhub:List*",
          "securityhub:Describe*",
          "config:Get*",
          "config:List*",
          "config:Describe*",
          "config:Select*",
          "cloudtrail:Get*",
          "cloudtrail:List*",
          "cloudtrail:Describe*",
          "cloudtrail:LookupEvents",
          "iam:Get*",
          "iam:List*",
          "iam:GenerateCredentialReport",
          "iam:GenerateServiceLastAccessedDetails",
          "kms:Get*",
          "kms:List*",
          "kms:Describe*",
          "secretsmanager:Get*",
          "secretsmanager:List*",
          "secretsmanager:Describe*",
          "access-analyzer:Get*",
          "access-analyzer:List*",
          "logs:Describe*",
          "logs:Get*",
          "logs:FilterLogEvents",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "cloudwatch:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Incident Response Role
resource "aws_iam_role" "incident_response" {
  count = var.create_security_roles ? 1 : 0

  name = "${var.project_name}-${var.environment}-incident-response"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-incident-response"
    Purpose     = "incident-response"
    Module      = "security"
  })
}

resource "aws_iam_role_policy" "incident_response" {
  count = var.create_security_roles ? 1 : 0

  name = "${var.project_name}-${var.environment}-incident-response-policy"
  role = aws_iam_role.incident_response[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # Investigation permissions
          "cloudtrail:LookupEvents",
          "logs:FilterLogEvents",
          "logs:GetLogEvents",
          "guardduty:GetFindings",
          "guardduty:ListFindings",
          "securityhub:GetFindings",
          "config:GetComplianceDetailsByConfigRule",
          "config:GetComplianceDetailsByResource",
          
          # Response permissions
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:StopInstances",
          "ec2:TerminateInstances",
          
          # WAF response
          "wafv2:UpdateWebAcl",
          "wafv2:UpdateIPSet",
          
          # IAM response
          "iam:AttachUserPolicy",
          "iam:DetachUserPolicy",
          "iam:PutUserPolicy",
          "iam:DeleteUserPolicy",
          "iam:UpdateAccessKey",
          "iam:DeleteAccessKey",
          
          # S3 response
          "s3:PutBucketPolicy",
          "s3:PutBucketAcl",
          "s3:PutObjectAcl",
          
          # Notification
          "sns:Publish"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# Service-Linked Roles
# =============================================================================

# GuardDuty Service-Linked Role
resource "aws_iam_service_linked_role" "guardduty" {
  count = var.enable_guardduty ? 1 : 0

  aws_service_name = "guardduty.amazonaws.com"
  description      = "Service-linked role for GuardDuty"

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-guardduty-slr"
    Purpose     = "guardduty-service"
    Module      = "security"
  })
}

# Config Service-Linked Role
resource "aws_iam_service_linked_role" "config" {
  count = var.enable_config ? 1 : 0

  aws_service_name = "config.amazonaws.com"
  description      = "Service-linked role for AWS Config"

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-config-slr"
    Purpose     = "config-service"
    Module      = "security"
  })
}

# =============================================================================
# IAM Policies for Security Services
# =============================================================================

# CloudTrail Service Role
resource "aws_iam_role" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  name = "${var.project_name}-${var.environment}-cloudtrail-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-cloudtrail-role"
    Purpose     = "cloudtrail-service"
    Module      = "security"
  })
}

resource "aws_iam_role_policy" "cloudtrail" {
  count = var.enable_cloudtrail ? 1 : 0

  name = "${var.project_name}-${var.environment}-cloudtrail-policy"
  role = aws_iam_role.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/cloudtrail/*"
      }
    ]
  })
}

# Config Service Role
resource "aws_iam_role" "config" {
  count = var.enable_config ? 1 : 0

  name = "${var.project_name}-${var.environment}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-config-role"
    Purpose     = "config-service"
    Module      = "security"
  })
}

resource "aws_iam_role_policy_attachment" "config" {
  count = var.enable_config ? 1 : 0

  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  count = var.enable_config ? 1 : 0

  name = "${var.project_name}-${var.environment}-config-s3-policy"
  role = aws_iam_role.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = var.enable_config ? aws_s3_bucket.config[0].arn : ""
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = var.enable_config ? "${aws_s3_bucket.config[0].arn}/*" : ""
      }
    ]
  })
}

# VPC Flow Logs Role
resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name = "${var.project_name}-${var.environment}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-vpc-flow-logs-role"
    Purpose     = "vpc-flow-logs"
    Module      = "security"
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name = "${var.project_name}-${var.environment}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# Data Sources
# =============================================================================