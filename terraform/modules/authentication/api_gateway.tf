# =============================================================================
# AWS Education Platform - API Gateway Configuration
# =============================================================================

# =============================================================================
# API Gateway REST API
# =============================================================================

resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.name_prefix}-api"
  description = "Education Platform API Gateway"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  # Binary media types for file uploads
  binary_media_types = [
    "application/octet-stream",
    "image/*",
    "video/*",
    "audio/*"
  ]

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-api-gateway"
    Purpose   = "api-management"
    Component = "api-gateway"
  })
}

# =============================================================================
# Cognito Authorizer
# =============================================================================

resource "aws_api_gateway_authorizer" "cognito" {
  name          = "${var.name_prefix}-cognito-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.main.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.main.arn]

  identity_source = "method.request.header.Authorization"
}

# =============================================================================
# API Resources and Methods
# =============================================================================

# Auth resource
resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "auth"
}

# Login resource
resource "aws_api_gateway_resource" "login" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "login"
}

# Register resource
resource "aws_api_gateway_resource" "register" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "register"
}

# Verify resource
resource "aws_api_gateway_resource" "verify" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "verify"
}

# Refresh resource
resource "aws_api_gateway_resource" "refresh" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "refresh"
}

# =============================================================================
# POST /auth/login
# =============================================================================

resource "aws_api_gateway_method" "login_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.login.id
  http_method   = "POST"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.main.id
}

resource "aws_api_gateway_integration" "login_post" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.login.id
  http_method = aws_api_gateway_method.login_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.auth_handler.invoke_arn
}

# =============================================================================
# POST /auth/register
# =============================================================================

resource "aws_api_gateway_method" "register_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.register.id
  http_method   = "POST"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.main.id
}

resource "aws_api_gateway_integration" "register_post" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.register.id
  http_method = aws_api_gateway_method.register_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.auth_handler.invoke_arn
}

# =============================================================================
# POST /auth/verify
# =============================================================================

resource "aws_api_gateway_method" "verify_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.verify.id
  http_method   = "POST"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.main.id
}

resource "aws_api_gateway_integration" "verify_post" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.verify.id
  http_method = aws_api_gateway_method.verify_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.auth_handler.invoke_arn
}

# =============================================================================
# POST /auth/refresh
# =============================================================================

resource "aws_api_gateway_method" "refresh_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.refresh.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_validator_id = aws_api_gateway_request_validator.main.id
}

resource "aws_api_gateway_integration" "refresh_post" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.refresh.id
  http_method = aws_api_gateway_method.refresh_post.http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.auth_handler.invoke_arn
}

# =============================================================================
# CORS Configuration
# =============================================================================

# Enable CORS for all auth endpoints
resource "aws_api_gateway_method" "auth_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.auth.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.auth.id
  http_method = aws_api_gateway_method.auth_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "auth_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.auth.id
  http_method = aws_api_gateway_method.auth_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "auth_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.auth.id
  http_method = aws_api_gateway_method.auth_options.http_method
  status_code = aws_api_gateway_method_response.auth_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'${join(",", var.api_gateway_config.cors_allow_headers)}'"
    "method.response.header.Access-Control-Allow-Methods" = "'${join(",", var.api_gateway_config.cors_allow_methods)}'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${join(",", var.api_gateway_config.cors_allow_origins)}'"
  }
}

# =============================================================================
# Request Validator
# =============================================================================

resource "aws_api_gateway_request_validator" "main" {
  name                        = "${var.name_prefix}-request-validator"
  rest_api_id                 = aws_api_gateway_rest_api.main.id
  validate_request_body       = true
  validate_request_parameters = true
}

# =============================================================================
# API Gateway Models
# =============================================================================

resource "aws_api_gateway_model" "login_request" {
  rest_api_id  = aws_api_gateway_rest_api.main.id
  name         = "LoginRequest"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Login Request Schema"
    type      = "object"
    properties = {
      username = {
        type        = "string"
        minLength   = 3
        maxLength   = 100
        description = "User email or username"
      }
      password = {
        type        = "string"
        minLength   = 8
        maxLength   = 128
        description = "User password"
      }
    }
    required = ["username", "password"]
  })
}

resource "aws_api_gateway_model" "register_request" {
  rest_api_id  = aws_api_gateway_rest_api.main.id
  name         = "RegisterRequest"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Register Request Schema"
    type      = "object"
    properties = {
      email = {
        type        = "string"
        format      = "email"
        description = "User email address"
      }
      password = {
        type        = "string"
        minLength   = 8
        maxLength   = 128
        description = "User password"
      }
      student_id = {
        type        = "string"
        minLength   = 5
        maxLength   = 20
        description = "Student ID (optional)"
      }
      department = {
        type        = "string"
        minLength   = 2
        maxLength   = 50
        description = "Department (optional)"
      }
      role = {
        type        = "string"
        enum        = ["student", "teacher", "admin"]
        description = "User role"
      }
    }
    required = ["email", "password", "role"]
  })
}

# =============================================================================
# Usage Plan and API Key
# =============================================================================

resource "aws_api_gateway_usage_plan" "main" {
  name = "${var.name_prefix}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  quota_settings {
    limit  = 10000
    period = "DAY"
  }

  throttle_settings {
    burst_limit = var.api_gateway_config.throttle_burst_limit
    rate_limit  = var.api_gateway_config.throttle_rate_limit
  }

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-usage-plan"
    Purpose   = "api-throttling"
    Component = "api-gateway"
  })
}

# =============================================================================
# Deployment and Stage
# =============================================================================

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.auth.id,
      aws_api_gateway_method.login_post.id,
      aws_api_gateway_integration.login_post.id,
      aws_api_gateway_method.register_post.id,
      aws_api_gateway_integration.register_post.id,
      aws_api_gateway_method.verify_post.id,
      aws_api_gateway_integration.verify_post.id,
      aws_api_gateway_method.refresh_post.id,
      aws_api_gateway_integration.refresh_post.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  # Enable logging
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      ip             = "$context.identity.sourceIp"
      userAgent      = "$context.identity.userAgent"
      error          = "$context.error.message"
      errorType      = "$context.error.messageString"
    })
  }

  # X-Ray tracing
  xray_tracing_enabled = true

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-api-stage"
    Purpose   = "api-deployment"
    Component = "api-gateway"
  })
}

# =============================================================================
# CloudWatch Log Group for API Gateway
# =============================================================================

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.name_prefix}"
  retention_in_days = var.cloudwatch_log_retention

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-api-gateway-logs"
    Purpose   = "api-logging"
    Component = "cloudwatch"
  })
}

# =============================================================================
# Custom Domain (Optional)
# =============================================================================

resource "aws_api_gateway_domain_name" "custom" {
  count           = var.domain_name != "" ? 1 : 0
  domain_name     = "api.${var.domain_name}"
  certificate_arn = aws_acm_certificate.api_cert[0].arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-custom-domain"
    Purpose   = "custom-domain"
    Component = "api-gateway"
  })
}

resource "aws_api_gateway_base_path_mapping" "custom" {
  count       = var.domain_name != "" ? 1 : 0
  api_id      = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  domain_name = aws_api_gateway_domain_name.custom[0].domain_name
}

# SSL Certificate for custom domain
resource "aws_acm_certificate" "api_cert" {
  count           = var.domain_name != "" ? 1 : 0
  domain_name     = "api.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-api-certificate"
    Purpose   = "ssl-certificate"
    Component = "acm"
  })
}
