# =============================================================================
# AWS Education Platform - Cognito User Pool Configuration
# =============================================================================
#
# This file configures AWS Cognito User Pool for user authentication
# including user groups, policies, and identity pool integration.
# =============================================================================

# =============================================================================
# Cognito User Pool
# =============================================================================

resource "aws_cognito_user_pool" "main" {
  name = "${var.name_prefix}-user-pool"

  # User attributes
  alias_attributes         = ["email", "preferred_username"]
  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]

  # User pool policies
  password_policy {
    minimum_length                   = var.password_minimum_length
    require_lowercase                = var.password_require_lowercase
    require_numbers                  = var.password_require_numbers
    require_symbols                  = var.password_require_symbols
    require_uppercase                = var.password_require_uppercase
    temporary_password_validity_days = 7
  }

  # Device configuration
  device_configuration {
    challenge_required_on_new_device      = false
    device_only_remembered_on_user_prompt = true
  }

  # MFA configuration
  mfa_configuration = var.enable_mfa ? "ON" : "OFF"

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # SMS configuration (if MFA is enabled)
  dynamic "sms_configuration" {
    for_each = var.enable_mfa ? [1] : []
    content {
      external_id    = "${var.name_prefix}-external"
      sns_caller_arn = aws_iam_role.cognito_sms_role[0].arn
    }
  }

  # User pool add-ons
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  # Verification message template
  verification_message_template {
    default_email_option  = "CONFIRM_WITH_CODE"
    email_message         = "Your verification code for Education Platform is {####}. Please enter this code to verify your email address."
    email_subject         = "Education Platform Email Verification"
    sms_message          = "Your verification code is {####}"
  }

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-user-pool"
    Purpose     = "user-authentication"
    Component   = "cognito"
  })
}

# =============================================================================
# IAM Role for Cognito SMS (if MFA is enabled)
# =============================================================================

resource "aws_iam_role" "cognito_sms_role" {
  count = var.enable_mfa ? 1 : 0
  name  = "${var.name_prefix}-cognito-sms-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cognito-idp.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "${var.name_prefix}-external"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-cognito-sms-role"
    Purpose   = "cognito-sms"
    Component = "iam"
  })
}

resource "aws_iam_role_policy_attachment" "cognito_sms_policy" {
  count      = var.enable_mfa ? 1 : 0
  role       = aws_iam_role.cognito_sms_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonCognitoIdpServiceRolePolicy"
}

# =============================================================================
# Cognito User Pool Domain
# =============================================================================

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.name_prefix}-auth"
  user_pool_id = aws_cognito_user_pool.main.id
}

# =============================================================================
# Cognito User Pool Client
# =============================================================================

resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.name_prefix}-app-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # OAuth configuration
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]
  
  # Callback URLs (adjust based on your frontend)
  callback_urls = [
    "http://localhost:3000/callback",
    "https://${var.domain_name != "" ? var.domain_name : "example.com"}/callback"
  ]
  
  logout_urls = [
    "http://localhost:3000/logout",
    "https://${var.domain_name != "" ? var.domain_name : "example.com"}/logout"
  ]

  # Client settings
  generate_secret                      = true
  prevent_user_existence_errors       = "ENABLED"
  enable_token_revocation             = true
  enable_propagate_additional_user_context_data = false

  # Token validity
  access_token_validity  = 1    # 1 hour
  id_token_validity     = 1    # 1 hour
  refresh_token_validity = 30   # 30 days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Read and write attributes
  read_attributes = [
    "email",
    "email_verified",
    "custom:student_id",
    "custom:department",
    "custom:role"
  ]

  write_attributes = [
    "email",
    "custom:student_id",
    "custom:department",
    "custom:role"
  ]

  # Explicit auth flows
  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_CUSTOM_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  supported_identity_providers = ["COGNITO"]
}

# =============================================================================
# Cognito Identity Pool
# =============================================================================

resource "aws_cognito_identity_pool" "main" {
  identity_pool_name               = "${var.name_prefix}-identity-pool"
  allow_unauthenticated_identities = false
  allow_classic_flow              = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.main.id
    provider_name           = aws_cognito_user_pool.main.endpoint
    server_side_token_check = true
  }

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-identity-pool"
    Purpose     = "identity-federation"
    Component   = "cognito"
  })
}

# =============================================================================
# User Groups
# =============================================================================

resource "aws_cognito_user_group" "students" {
  name         = "students"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Student user group"
  precedence   = 30
  role_arn     = aws_iam_role.students_role.arn
}

resource "aws_cognito_user_group" "teachers" {
  name         = "teachers"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Teacher user group"
  precedence   = 20
  role_arn     = aws_iam_role.teachers_role.arn
}

resource "aws_cognito_user_group" "admins" {
  name         = "admins"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Administrator user group"
  precedence   = 10
  role_arn     = aws_iam_role.admins_role.arn
}

# =============================================================================
# IAM Roles for User Groups
# =============================================================================

# Students role
resource "aws_iam_role" "students_role" {
  name = "${var.name_prefix}-students-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.main.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-students-role"
    Purpose   = "student-permissions"
    Component = "iam"
  })
}

resource "aws_iam_role_policy" "students_policy" {
  name = "${var.name_prefix}-students-policy"
  role = aws_iam_role.students_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.name_prefix}-student-content/*"
        ]
      }
    ]
  })
}

# Teachers role
resource "aws_iam_role" "teachers_role" {
  name = "${var.name_prefix}-teachers-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.main.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-teachers-role"
    Purpose   = "teacher-permissions"
    Component = "iam"
  })
}

resource "aws_iam_role_policy" "teachers_policy" {
  name = "${var.name_prefix}-teachers-policy"
  role = aws_iam_role.teachers_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.name_prefix}-teacher-content/*",
          "arn:aws:s3:::${var.name_prefix}-student-content/*"
        ]
      }
    ]
  })
}

# Admins role
resource "aws_iam_role" "admins_role" {
  name = "${var.name_prefix}-admins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.main.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-admins-role"
    Purpose   = "admin-permissions"
    Component = "iam"
  })
}

resource "aws_iam_role_policy" "admins_policy" {
  name = "${var.name_prefix}-admins-policy"
  role = aws_iam_role.admins_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*",
          "cognito-idp:*",
          "logs:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# Identity Pool Role Attachment
# =============================================================================

resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = aws_cognito_identity_pool.main.id

  roles = {
    "authenticated" = aws_iam_role.authenticated_role.arn
  }

  role_mapping {
    identity_provider         = "${aws_cognito_user_pool.main.endpoint}:${aws_cognito_user_pool_client.main.id}"
    ambiguous_role_resolution = "AuthenticatedRole"
    type                      = "Token"
  }
}

# Default authenticated role
resource "aws_iam_role" "authenticated_role" {
  name = "${var.name_prefix}-authenticated-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.main.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-authenticated-role"
    Purpose   = "default-authenticated-permissions"
    Component = "iam"
  })
}

resource "aws_iam_role_policy" "authenticated_policy" {
  name = "${var.name_prefix}-authenticated-policy"
  role = aws_iam_role.authenticated_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-sync:*",
          "cognito-identity:*"
        ]
        Resource = "*"
      }
    ]
  })
}
