# Chat Module Outputs

# AppSync API
output "appsync_api_id" {
  description = "AppSync API ID"
  value       = aws_appsync_graphql_api.chat_api.id
}

output "appsync_api_uris" {
  description = "AppSync API URIs"
  value = {
    graphql    = aws_appsync_graphql_api.chat_api.uris["GRAPHQL"]
    realtime   = aws_appsync_graphql_api.chat_api.uris["REALTIME"]
  }
}

output "appsync_api_arn" {
  description = "AppSync API ARN"
  value       = aws_appsync_graphql_api.chat_api.arn
}

output "appsync_api_name" {
  description = "AppSync API name"
  value       = aws_appsync_graphql_api.chat_api.name
}

# DynamoDB Tables
output "chat_messages_table_name" {
  description = "Chat messages DynamoDB table name"
  value       = aws_dynamodb_table.chat_messages.name
}

output "chat_messages_table_arn" {
  description = "Chat messages DynamoDB table ARN"
  value       = aws_dynamodb_table.chat_messages.arn
}

output "chat_rooms_table_name" {
  description = "Chat rooms DynamoDB table name"
  value       = aws_dynamodb_table.chat_rooms.name
}

output "chat_rooms_table_arn" {
  description = "Chat rooms DynamoDB table ARN"
  value       = aws_dynamodb_table.chat_rooms.arn
}

output "room_members_table_name" {
  description = "Room members DynamoDB table name"
  value       = aws_dynamodb_table.room_members.name
}

output "room_members_table_arn" {
  description = "Room members DynamoDB table ARN"
  value       = aws_dynamodb_table.room_members.arn
}

output "user_presence_table_name" {
  description = "User presence DynamoDB table name"
  value       = aws_dynamodb_table.user_presence.name
}

output "user_presence_table_arn" {
  description = "User presence DynamoDB table ARN"
  value       = aws_dynamodb_table.user_presence.arn
}

# OpenSearch Domain
output "opensearch_domain_endpoint" {
  description = "OpenSearch domain endpoint"
  value       = var.enable_opensearch ? aws_opensearch_domain.chat_search[0].endpoint : null
}

output "opensearch_domain_arn" {
  description = "OpenSearch domain ARN"
  value       = var.enable_opensearch ? aws_opensearch_domain.chat_search[0].arn : null
}

output "opensearch_kibana_endpoint" {
  description = "OpenSearch Kibana endpoint"
  value       = var.enable_opensearch ? aws_opensearch_domain.chat_search[0].kibana_endpoint : null
}

# Lambda Functions
output "chat_resolver_function_name" {
  description = "Chat resolver Lambda function name"
  value       = aws_lambda_function.chat_resolver.function_name
}

output "chat_resolver_function_arn" {
  description = "Chat resolver Lambda function ARN"
  value       = aws_lambda_function.chat_resolver.arn
}

output "message_processor_function_name" {
  description = "Message processor Lambda function name"
  value       = aws_lambda_function.message_processor.function_name
}

output "message_processor_function_arn" {
  description = "Message processor Lambda function ARN"
  value       = aws_lambda_function.message_processor.arn
}

# IAM Roles
output "appsync_service_role_arn" {
  description = "AppSync service role ARN"
  value       = aws_iam_role.appsync_service_role.arn
}

output "lambda_execution_role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.lambda_execution_role.arn
}

# Security Groups
output "lambda_security_group_id" {
  description = "Lambda security group ID"
  value       = aws_security_group.lambda_sg.id
}

output "opensearch_security_group_id" {
  description = "OpenSearch security group ID"
  value       = var.enable_opensearch ? aws_security_group.opensearch_sg[0].id : null
}

# CloudWatch Log Groups
output "appsync_log_group_name" {
  description = "AppSync CloudWatch log group name"
  value       = aws_cloudwatch_log_group.appsync_logs.name
}

output "lambda_log_group_names" {
  description = "Lambda CloudWatch log group names"
  value = {
    chat_resolver      = aws_cloudwatch_log_group.chat_resolver_logs.name
    message_processor  = aws_cloudwatch_log_group.message_processor_logs.name
  }
}

# Configuration Values
output "chat_configuration" {
  description = "Chat configuration values for frontend"
  value = {
    max_message_length      = var.max_message_length
    max_room_members       = var.max_room_members
    typing_indicator_timeout = var.typing_indicator_timeout
    presence_timeout       = var.presence_timeout
  }
}

# All DynamoDB table names for easy reference
output "all_table_names" {
  description = "All chat-related DynamoDB table names"
  value = {
    messages     = aws_dynamodb_table.chat_messages.name
    rooms        = aws_dynamodb_table.chat_rooms.name
    room_members = aws_dynamodb_table.room_members.name
    presence     = aws_dynamodb_table.user_presence.name
  }
}

# GraphQL Schema
output "graphql_schema" {
  description = "GraphQL schema content"
  value       = data.local_file.graphql_schema.content
}
