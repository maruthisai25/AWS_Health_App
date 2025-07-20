# =============================================================================
# API Gateway Resources for Attendance System
# =============================================================================

# Create attendance resource only if API Gateway ID is provided
resource "aws_api_gateway_resource" "attendance" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  parent_id   = var.api_gateway_root_resource_id
  path_part   = "attendance"
}

# =============================================================================
# Check-in Endpoint
# =============================================================================

resource "aws_api_gateway_resource" "check_in" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  parent_id   = aws_api_gateway_resource.attendance[0].id
  path_part   = "check-in"
}

resource "aws_api_gateway_method" "check_in" {
  count         = var.api_gateway_id != "" ? 1 : 0
  rest_api_id   = var.api_gateway_id
  resource_id   = aws_api_gateway_resource.check_in[0].id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = var.api_gateway_id != "" ? data.aws_api_gateway_authorizers.cognito[0].ids[0] : null

  request_validator_id = aws_api_gateway_request_validator.attendance[0].id
  request_models = {
    "application/json" = aws_api_gateway_model.check_in_request[0].name
  }
}

resource "aws_api_gateway_integration" "check_in" {
  count                   = var.api_gateway_id != "" ? 1 : 0
  rest_api_id             = var.api_gateway_id
  resource_id             = aws_api_gateway_resource.check_in[0].id
  http_method             = aws_api_gateway_method.check_in[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.attendance_tracker.invoke_arn
}

resource "aws_api_gateway_method_response" "check_in" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  resource_id = aws_api_gateway_resource.check_in[0].id
  http_method = aws_api_gateway_method.check_in[0].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "check_in" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  resource_id = aws_api_gateway_resource.check_in[0].id
  http_method = aws_api_gateway_method.check_in[0].http_method
  status_code = aws_api_gateway_method_response.check_in[0].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
  }
}

# =============================================================================
# Check-out Endpoint
# =============================================================================

resource "aws_api_gateway_resource" "check_out" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  parent_id   = aws_api_gateway_resource.attendance[0].id
  path_part   = "check-out"
}

resource "aws_api_gateway_method" "check_out" {
  count         = var.api_gateway_id != "" ? 1 : 0
  rest_api_id   = var.api_gateway_id
  resource_id   = aws_api_gateway_resource.check_out[0].id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = var.api_gateway_id != "" ? data.aws_api_gateway_authorizers.cognito[0].ids[0] : null

  request_validator_id = aws_api_gateway_request_validator.attendance[0].id
  request_models = {
    "application/json" = aws_api_gateway_model.check_out_request[0].name
  }
}

resource "aws_api_gateway_integration" "check_out" {
  count                   = var.api_gateway_id != "" ? 1 : 0
  rest_api_id             = var.api_gateway_id
  resource_id             = aws_api_gateway_resource.check_out[0].id
  http_method             = aws_api_gateway_method.check_out[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.attendance_tracker.invoke_arn
}

# =============================================================================
# Status Endpoint (GET /attendance/status/{userId})
# =============================================================================

resource "aws_api_gateway_resource" "status" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  parent_id   = aws_api_gateway_resource.attendance[0].id
  path_part   = "status"
}

resource "aws_api_gateway_resource" "status_user" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  parent_id   = aws_api_gateway_resource.status[0].id
  path_part   = "{userId}"
}

resource "aws_api_gateway_method" "status" {
  count         = var.api_gateway_id != "" ? 1 : 0
  rest_api_id   = var.api_gateway_id
  resource_id   = aws_api_gateway_resource.status_user[0].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = var.api_gateway_id != "" ? data.aws_api_gateway_authorizers.cognito[0].ids[0] : null

  request_parameters = {
    "method.request.path.userId" = true
  }
}

resource "aws_api_gateway_integration" "status" {
  count                   = var.api_gateway_id != "" ? 1 : 0
  rest_api_id             = var.api_gateway_id
  resource_id             = aws_api_gateway_resource.status_user[0].id
  http_method             = aws_api_gateway_method.status[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.attendance_tracker.invoke_arn
}

# =============================================================================
# History Endpoint (GET /attendance/history/{userId})
# =============================================================================

resource "aws_api_gateway_resource" "history" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  parent_id   = aws_api_gateway_resource.attendance[0].id
  path_part   = "history"
}

resource "aws_api_gateway_resource" "history_user" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  parent_id   = aws_api_gateway_resource.history[0].id
  path_part   = "{userId}"
}

resource "aws_api_gateway_method" "history" {
  count         = var.api_gateway_id != "" ? 1 : 0
  rest_api_id   = var.api_gateway_id
  resource_id   = aws_api_gateway_resource.history_user[0].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = var.api_gateway_id != "" ? data.aws_api_gateway_authorizers.cognito[0].ids[0] : null

  request_parameters = {
    "method.request.path.userId"      = true
    "method.request.querystring.from" = false
    "method.request.querystring.to"   = false
    "method.request.querystring.limit" = false
  }
}

resource "aws_api_gateway_integration" "history" {
  count                   = var.api_gateway_id != "" ? 1 : 0
  rest_api_id             = var.api_gateway_id
  resource_id             = aws_api_gateway_resource.history_user[0].id
  http_method             = aws_api_gateway_method.history[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.attendance_tracker.invoke_arn
}

# =============================================================================
# Class QR Code Endpoint (POST /attendance/class/{classId}/qr)
# =============================================================================

resource "aws_api_gateway_resource" "class" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  parent_id   = aws_api_gateway_resource.attendance[0].id
  path_part   = "class"
}

resource "aws_api_gateway_resource" "class_id" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  parent_id   = aws_api_gateway_resource.class[0].id
  path_part   = "{classId}"
}

resource "aws_api_gateway_resource" "qr" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  parent_id   = aws_api_gateway_resource.class_id[0].id
  path_part   = "qr"
}

resource "aws_api_gateway_method" "qr" {
  count         = var.api_gateway_id != "" ? 1 : 0
  rest_api_id   = var.api_gateway_id
  resource_id   = aws_api_gateway_resource.qr[0].id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = var.api_gateway_id != "" ? data.aws_api_gateway_authorizers.cognito[0].ids[0] : null

  request_parameters = {
    "method.request.path.classId" = true
  }
}

resource "aws_api_gateway_integration" "qr" {
  count                   = var.api_gateway_id != "" ? 1 : 0
  rest_api_id             = var.api_gateway_id
  resource_id             = aws_api_gateway_resource.qr[0].id
  http_method             = aws_api_gateway_method.qr[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.attendance_tracker.invoke_arn
}

# =============================================================================
# Reports Endpoint (GET /attendance/reports)
# =============================================================================

resource "aws_api_gateway_resource" "reports" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  parent_id   = aws_api_gateway_resource.attendance[0].id
  path_part   = "reports"
}

resource "aws_api_gateway_method" "reports" {
  count         = var.api_gateway_id != "" ? 1 : 0
  rest_api_id   = var.api_gateway_id
  resource_id   = aws_api_gateway_resource.reports[0].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = var.api_gateway_id != "" ? data.aws_api_gateway_authorizers.cognito[0].ids[0] : null

  request_parameters = {
    "method.request.querystring.type"      = false
    "method.request.querystring.from"      = false
    "method.request.querystring.to"        = false
    "method.request.querystring.format"    = false
    "method.request.querystring.classId"   = false
    "method.request.querystring.courseCode" = false
  }
}

resource "aws_api_gateway_integration" "reports" {
  count                   = var.api_gateway_id != "" ? 1 : 0
  rest_api_id             = var.api_gateway_id
  resource_id             = aws_api_gateway_resource.reports[0].id
  http_method             = aws_api_gateway_method.reports[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.attendance_reporter.invoke_arn
}

# =============================================================================
# Analytics Endpoint (GET /attendance/analytics)
# =============================================================================

resource "aws_api_gateway_resource" "analytics" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  parent_id   = aws_api_gateway_resource.attendance[0].id
  path_part   = "analytics"
}

resource "aws_api_gateway_method" "analytics" {
  count         = var.api_gateway_id != "" ? 1 : 0
  rest_api_id   = var.api_gateway_id
  resource_id   = aws_api_gateway_resource.analytics[0].id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = var.api_gateway_id != "" ? data.aws_api_gateway_authorizers.cognito[0].ids[0] : null

  request_parameters = {
    "method.request.querystring.period"    = false
    "method.request.querystring.classId"   = false
    "method.request.querystring.courseCode" = false
    "method.request.querystring.userId"    = false
  }
}

resource "aws_api_gateway_integration" "analytics" {
  count                   = var.api_gateway_id != "" ? 1 : 0
  rest_api_id             = var.api_gateway_id
  resource_id             = aws_api_gateway_resource.analytics[0].id
  http_method             = aws_api_gateway_method.analytics[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.attendance_reporter.invoke_arn
}

# =============================================================================
# CORS Support for All Endpoints
# =============================================================================

# CORS for attendance resource
resource "aws_api_gateway_method" "attendance_options" {
  count         = var.api_gateway_id != "" ? 1 : 0
  rest_api_id   = var.api_gateway_id
  resource_id   = aws_api_gateway_resource.attendance[0].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "attendance_options" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  resource_id = aws_api_gateway_resource.attendance[0].id
  http_method = aws_api_gateway_method.attendance_options[0].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "attendance_options" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  resource_id = aws_api_gateway_resource.attendance[0].id
  http_method = aws_api_gateway_method.attendance_options[0].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "attendance_options" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
  resource_id = aws_api_gateway_resource.attendance[0].id
  http_method = aws_api_gateway_method.attendance_options[0].http_method
  status_code = aws_api_gateway_method_response.attendance_options[0].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
  }
}

# =============================================================================
# Request Validation and Models
# =============================================================================

resource "aws_api_gateway_request_validator" "attendance" {
  count                       = var.api_gateway_id != "" ? 1 : 0
  name                        = "${var.project_name}-${var.environment}-attendance-validator"
  rest_api_id                 = var.api_gateway_id
  validate_request_body       = true
  validate_request_parameters = true
}

# Check-in request model
resource "aws_api_gateway_model" "check_in_request" {
  count        = var.api_gateway_id != "" ? 1 : 0
  rest_api_id  = var.api_gateway_id
  name         = "CheckInRequest"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Check-in Request Schema"
    type      = "object"
    required  = ["classId"]
    properties = {
      classId = {
        type = "string"
        description = "Unique identifier for the class"
      }
      qrCode = {
        type = "string"
        description = "QR code for attendance verification"
      }
      location = {
        type = "object"
        properties = {
          latitude = {
            type = "number"
            minimum = -90
            maximum = 90
          }
          longitude = {
            type = "number"
            minimum = -180
            maximum = 180
          }
        }
        required = ["latitude", "longitude"]
      }
      timestamp = {
        type = "string"
        format = "date-time"
        description = "ISO 8601 timestamp of check-in attempt"
      }
    }
  })
}

# Check-out request model
resource "aws_api_gateway_model" "check_out_request" {
  count        = var.api_gateway_id != "" ? 1 : 0
  rest_api_id  = var.api_gateway_id
  name         = "CheckOutRequest"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Check-out Request Schema"
    type      = "object"
    required  = ["attendanceId"]
    properties = {
      attendanceId = {
        type = "string"
        description = "Unique identifier for the attendance record"
      }
      location = {
        type = "object"
        properties = {
          latitude = {
            type = "number"
            minimum = -90
            maximum = 90
          }
          longitude = {
            type = "number"
            minimum = -180
            maximum = 180
          }
        }
        required = ["latitude", "longitude"]
      }
      timestamp = {
        type = "string"
        format = "date-time"
        description = "ISO 8601 timestamp of check-out attempt"
      }
    }
  })
}

# =============================================================================
# Lambda Permissions for API Gateway
# =============================================================================

resource "aws_lambda_permission" "attendance_tracker_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.attendance_tracker.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = var.api_gateway_execution_arn != "" ? "${var.api_gateway_execution_arn}/*/*" : null
}

resource "aws_lambda_permission" "attendance_reporter_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.attendance_reporter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = var.api_gateway_execution_arn != "" ? "${var.api_gateway_execution_arn}/*/*" : null
}

# =============================================================================
# Data Sources
# =============================================================================

data "aws_api_gateway_authorizers" "cognito" {
  count       = var.api_gateway_id != "" ? 1 : 0
  rest_api_id = var.api_gateway_id
}