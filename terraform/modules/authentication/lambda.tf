# =============================================================================
# AWS Education Platform - Lambda Functions for Authentication
# =============================================================================

# Data sources
data "archive_file" "auth_handler" {
  type        = "zip"
  source_dir  = "${path.module}/../../../applications/lambda-functions/auth-handler"
  output_path = "${path.module}/auth-handler.zip"
}

data "archive_file" "pre_signup" {
  count       = var.cognito_lambda_config.pre_signup ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../../applications/lambda-functions/pre-signup"
  output_path = "${path.module}/pre-signup.zip"
}

data "archive_file" "post_confirmation" {
  count       = var.cognito_lambda_config.post_confirmation ? 1 : 0
  type        = "zip"
  source_dir  = "${path.module}/../../../applications/lambda-functions/post-confirmation"
  output_path = "${path.module}/post-confirmation.zip"
}

# =============================================================================
# Security Group for Lambda Functions
# =============================================================================

resource "aws_security_group" "lambda_sg" {
  name_prefix = "${var.name_prefix}-lambda-"
  vpc_id      = var.vpc_id
  description = "Security group for authentication Lambda functions"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-lambda-sg"
    Purpose   = "lambda-security"
    Component = "security-group"
  })
}

# =============================================================================
# IAM Role for Lambda Functions
# =============================================================================

resource "aws_iam_role" "lambda_role" {
  name = "${var.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-lambda-role"
    Purpose   = "lambda-permissions"
    Component = "iam"
  })
}

# Lambda execution policy
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.name_prefix}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:AdminCreateUser",
          "cognito-idp:AdminSetUserPassword",
          "cognito-idp:AdminGetUser",
          "cognito-idp:AdminUpdateUserAttributes",
          "cognito-idp:AdminDisableUser",
          "cognito-idp:AdminEnableUser",
          "cognito-idp:AdminDeleteUser",
          "cognito-idp:ListUsers",
          "cognito-idp:ConfirmForgotPassword",
          "cognito-idp:ChangePassword",
          "cognito-idp:GetUser",
          "cognito-idp:UpdateUserAttributes",
          "cognito-idp:VerifyUserAttribute",
          "cognito-idp:SignUp"
        ]
        Resource = [
          aws_cognito_user_pool.main.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name_prefix}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# =============================================================================
# CloudWatch Log Groups for Lambda Functions
# =============================================================================

resource "aws_cloudwatch_log_group" "auth_handler" {
  name              = "/aws/lambda/${aws_lambda_function.auth_handler.function_name}"
  retention_in_days = var.cloudwatch_log_retention

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-auth-handler-logs"
    Purpose   = "lambda-logging"
    Component = "cloudwatch"
  })
}

resource "aws_cloudwatch_log_group" "pre_signup" {
  count             = var.cognito_lambda_config.pre_signup ? 1 : 0
  name              = "/aws/lambda/${aws_lambda_function.pre_signup[0].function_name}"
  retention_in_days = var.cloudwatch_log_retention

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-pre-signup-logs"
    Purpose   = "lambda-logging"
    Component = "cloudwatch"
  })
}

resource "aws_cloudwatch_log_group" "post_confirmation" {
  count             = var.cognito_lambda_config.post_confirmation ? 1 : 0
  name              = "/aws/lambda/${aws_lambda_function.post_confirmation[0].function_name}"
  retention_in_days = var.cloudwatch_log_retention

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-post-confirmation-logs"
    Purpose   = "lambda-logging"
    Component = "cloudwatch"
  })
}

# =============================================================================
# Main Authentication Handler Lambda Function
# =============================================================================

resource "aws_lambda_function" "auth_handler" {
  filename         = data.archive_file.auth_handler.output_path
  function_name    = "${var.name_prefix}-auth-handler"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.auth_handler.output_base64sha256
  runtime         = "nodejs18.x"
  timeout         = 30
  memory_size     = 256

  vpc_config {
    subnet_ids         = var.private_subnets
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      USER_POOL_ID        = aws_cognito_user_pool.main.id
      USER_POOL_CLIENT_ID = aws_cognito_user_pool_client.main.id
      REGION              = data.aws_region.current.name
      ENVIRONMENT         = var.environment
      KMS_KEY_ID          = var.kms_key_arn
    }
  }

  kms_key_arn = var.kms_key_arn

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.auth_handler,
  ]

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-auth-handler"
    Purpose   = "authentication-processing"
    Component = "lambda"
  })
}

# =============================================================================
# Pre-Signup Lambda Function
# =============================================================================

resource "aws_lambda_function" "pre_signup" {
  count            = var.cognito_lambda_config.pre_signup ? 1 : 0
  filename         = data.archive_file.pre_signup[0].output_path
  function_name    = "${var.name_prefix}-pre-signup"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.pre_signup[0].output_base64sha256
  runtime         = "nodejs18.x"
  timeout         = 10
  memory_size     = 128

  vpc_config {
    subnet_ids         = var.private_subnets
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      USER_POOL_ID = aws_cognito_user_pool.main.id
      REGION       = data.aws_region.current.name
      ENVIRONMENT  = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.pre_signup[0],
  ]

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-pre-signup"
    Purpose   = "pre-signup-validation"
    Component = "lambda"
  })
}

# =============================================================================
# Post-Confirmation Lambda Function
# =============================================================================

resource "aws_lambda_function" "post_confirmation" {
  count            = var.cognito_lambda_config.post_confirmation ? 1 : 0
  filename         = data.archive_file.post_confirmation[0].output_path
  function_name    = "${var.name_prefix}-post-confirmation"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.post_confirmation[0].output_base64sha256
  runtime         = "nodejs18.x"
  timeout         = 10
  memory_size     = 128

  vpc_config {
    subnet_ids         = var.private_subnets
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      USER_POOL_ID = aws_cognito_user_pool.main.id
      REGION       = data.aws_region.current.name
      ENVIRONMENT  = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.post_confirmation[0],
  ]

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-post-confirmation"
    Purpose   = "post-confirmation-setup"
    Component = "lambda"
  })
}

# =============================================================================
# Lambda Permissions for API Gateway
# =============================================================================

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# =============================================================================
# Lambda Permissions for Cognito
# =============================================================================

resource "aws_lambda_permission" "cognito_pre_signup" {
  count         = var.cognito_lambda_config.pre_signup ? 1 : 0
  statement_id  = "AllowExecutionFromCognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pre_signup[0].function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}

resource "aws_lambda_permission" "cognito_post_confirmation" {
  count         = var.cognito_lambda_config.post_confirmation ? 1 : 0
  statement_id  = "AllowExecutionFromCognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_confirmation[0].function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}

# =============================================================================
# Lambda Function Aliases for Blue/Green Deployments
# =============================================================================

resource "aws_lambda_alias" "auth_handler_live" {
  name             = "live"
  description      = "Live version of auth handler"
  function_name    = aws_lambda_function.auth_handler.function_name
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [function_version]
  }
}

resource "aws_lambda_alias" "pre_signup_live" {
  count            = var.cognito_lambda_config.pre_signup ? 1 : 0
  name             = "live"
  description      = "Live version of pre-signup"
  function_name    = aws_lambda_function.pre_signup[0].function_name
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [function_version]
  }
}

resource "aws_lambda_alias" "post_confirmation_live" {
  count            = var.cognito_lambda_config.post_confirmation ? 1 : 0
  name             = "live"
  description      = "Live version of post-confirmation"
  function_name    = aws_lambda_function.post_confirmation[0].function_name
  function_version = "$LATEST"

  lifecycle {
    ignore_changes = [function_version]
  }
}

# =============================================================================
# CloudWatch Alarms for Lambda Functions
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "auth_handler_errors" {
  alarm_name          = "${var.name_prefix}-auth-handler-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors auth handler lambda errors"
  
  dimensions = {
    FunctionName = aws_lambda_function.auth_handler.function_name
  }

  alarm_actions = [] # Add SNS topic ARN here for notifications

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-auth-handler-errors-alarm"
    Purpose   = "lambda-monitoring"
    Component = "cloudwatch"
  })
}

resource "aws_cloudwatch_metric_alarm" "auth_handler_duration" {
  alarm_name          = "${var.name_prefix}-auth-handler-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "25000"  # 25 seconds
  alarm_description   = "This metric monitors auth handler lambda duration"
  
  dimensions = {
    FunctionName = aws_lambda_function.auth_handler.function_name
  }

  alarm_actions = [] # Add SNS topic ARN here for notifications

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-auth-handler-duration-alarm"
    Purpose   = "lambda-monitoring"
    Component = "cloudwatch"
  })
}
