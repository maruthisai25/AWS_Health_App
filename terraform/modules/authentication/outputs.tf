# =============================================================================
# AWS Education Platform - Authentication Module Outputs
# =============================================================================

output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_endpoint" {
  description = "Endpoint name of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.endpoint
}

output "user_pool_domain" {
  description = "Cognito User Pool domain"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "user_pool_client_id" {
  description = "ID of the Cognito User Pool client"
  value       = aws_cognito_user_pool_client.main.id
}

output "user_pool_client_secret" {
  description = "Client secret of the Cognito User Pool client"
  value       = aws_cognito_user_pool_client.main.client_secret
  sensitive   = true
}

output "identity_pool_id" {
  description = "ID of the Cognito Identity Pool"
  value       = aws_cognito_identity_pool.main.id
}

output "api_gateway_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_root_resource_id" {
  description = "Resource ID of the API Gateway root resource"
  value       = aws_api_gateway_rest_api.main.root_resource_id
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway"
  value       = aws_api_gateway_deployment.main.invoke_url
}

output "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.main.stage_name
}

output "cognito_authorizer_id" {
  description = "ID of the Cognito authorizer for API Gateway"
  value       = aws_api_gateway_authorizer.cognito.id
}

output "auth_lambda_function_name" {
  description = "Name of the authentication Lambda function"
  value       = aws_lambda_function.auth_handler.function_name
}

output "auth_lambda_function_arn" {
  description = "ARN of the authentication Lambda function"
  value       = aws_lambda_function.auth_handler.arn
}

output "pre_signup_lambda_arn" {
  description = "ARN of the pre-signup Lambda function"
  value       = var.cognito_lambda_config.pre_signup ? aws_lambda_function.pre_signup[0].arn : null
}

output "post_confirmation_lambda_arn" {
  description = "ARN of the post-confirmation Lambda function"
  value       = var.cognito_lambda_config.post_confirmation ? aws_lambda_function.post_confirmation[0].arn : null
}

output "user_groups" {
  description = "Map of user group names to ARNs"
  value = {
    students = aws_cognito_user_group.students.name
    teachers = aws_cognito_user_group.teachers.name
    admins   = aws_cognito_user_group.admins.name
  }
}

output "security_group_id" {
  description = "ID of the security group for Lambda functions"
  value       = aws_security_group.lambda_sg.id
}

output "custom_domain_name" {
  description = "Custom domain name for API Gateway (if configured)"
  value       = var.domain_name != "" ? aws_api_gateway_domain_name.custom[0].domain_name : null
}

output "authentication_config" {
  description = "Authentication configuration summary"
  value = {
    user_pool_id          = aws_cognito_user_pool.main.id
    user_pool_client_id   = aws_cognito_user_pool_client.main.id
    identity_pool_id      = aws_cognito_identity_pool.main.id
    api_gateway_url       = aws_api_gateway_deployment.main.invoke_url
    cognito_domain        = aws_cognito_user_pool_domain.main.domain
    mfa_enabled          = var.enable_mfa
    custom_domain        = var.domain_name != "" ? aws_api_gateway_domain_name.custom[0].domain_name : null
  }
}
