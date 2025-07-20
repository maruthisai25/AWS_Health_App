# AppSync GraphQL API for Chat System

# GraphQL Schema Data Source
data "local_file" "graphql_schema" {
  filename = "${path.module}/schema.graphql"
}

# AppSync GraphQL API
resource "aws_appsync_graphql_api" "chat_api" {
  authentication_type = var.appsync_authentication_type
  name                = "${var.project_name}-${var.environment}-chat-api"
  schema              = data.local_file.graphql_schema.content

  # Additional authentication providers
  additional_authentication_provider {
    authentication_type = "AMAZON_COGNITO_USER_POOLS"
    user_pool_config {
      user_pool_id               = var.user_pool_id
      aws_region                 = data.aws_region.current.name
    }
  }

  # Lambda authorization configuration
  dynamic "lambda_authorizer_config" {
    for_each = var.appsync_authentication_type == "AWS_LAMBDA" ? [1] : []
    content {
      authorizer_uri                   = aws_lambda_function.auth_resolver.arn
      authorizer_result_ttl_in_seconds = 300
      identity_validation_expression   = "^Bearer [-0-9A-Za-z\\.]+$"
    }
  }

  # Logging configuration
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_service_role.arn
    field_log_level          = var.appsync_log_level
    exclude_verbose_content  = !var.enable_appsync_field_logs
  }

  # X-Ray tracing
  xray_enabled = var.appsync_xray_enabled

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chat-api"
    Type = "AppSync"
    Module = "chat"
  })
}

# AppSync Data Source for DynamoDB - Chat Messages
resource "aws_appsync_datasource" "chat_messages_datasource" {
  api_id           = aws_appsync_graphql_api.chat_api.id
  name             = "ChatMessagesDataSource"
  service_role_arn = aws_iam_role.appsync_service_role.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.chat_messages.name
    region     = data.aws_region.current.name
    
    # Enable versioned data source for conflict resolution
    versioned                = true
    delta_sync_config {
      base_table_ttl        = var.message_history_days * 24 * 60
      delta_sync_table_name = "${aws_dynamodb_table.chat_messages.name}-delta"
      delta_sync_table_ttl  = 30
    }
  }
}

# AppSync Data Source for DynamoDB - Chat Rooms
resource "aws_appsync_datasource" "chat_rooms_datasource" {
  api_id           = aws_appsync_graphql_api.chat_api.id
  name             = "ChatRoomsDataSource"
  service_role_arn = aws_iam_role.appsync_service_role.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.chat_rooms.name
    region     = data.aws_region.current.name
  }
}

# AppSync Data Source for DynamoDB - Room Members
resource "aws_appsync_datasource" "room_members_datasource" {
  api_id           = aws_appsync_graphql_api.chat_api.id
  name             = "RoomMembersDataSource"
  service_role_arn = aws_iam_role.appsync_service_role.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.room_members.name
    region     = data.aws_region.current.name
  }
}

# AppSync Data Source for DynamoDB - User Presence
resource "aws_appsync_datasource" "user_presence_datasource" {
  api_id           = aws_appsync_graphql_api.chat_api.id
  name             = "UserPresenceDataSource"
  service_role_arn = aws_iam_role.appsync_service_role.arn
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.user_presence.name
    region     = data.aws_region.current.name
  }
}

# AppSync Data Source for Lambda - Chat Resolver
resource "aws_appsync_datasource" "chat_resolver_datasource" {
  api_id           = aws_appsync_graphql_api.chat_api.id
  name             = "ChatResolverDataSource"
  service_role_arn = aws_iam_role.appsync_service_role.arn
  type             = "AWS_LAMBDA"

  lambda_config {
    function_arn = aws_lambda_function.chat_resolver.arn
  }
}

# AppSync Data Source for OpenSearch
resource "aws_appsync_datasource" "opensearch_datasource" {
  count = var.enable_opensearch ? 1 : 0
  
  api_id           = aws_appsync_graphql_api.chat_api.id
  name             = "OpenSearchDataSource"
  service_role_arn = aws_iam_role.appsync_service_role.arn
  type             = "AMAZON_ELASTICSEARCH"

  elasticsearch_config {
    endpoint = "https://${aws_opensearch_domain.chat_search[0].endpoint}"
    region   = data.aws_region.current.name
  }
}

# AppSync Function for Chat Message Creation
resource "aws_appsync_function" "create_message_function" {
  api_id                   = aws_appsync_graphql_api.chat_api.id
  data_source              = aws_appsync_datasource.chat_messages_datasource.name
  name                     = "CreateMessageFunction"
  request_mapping_template = file("${path.module}/resolvers/createMessage.request.vtl")
  response_mapping_template = file("${path.module}/resolvers/createMessage.response.vtl")
}

# AppSync Function for Message Search
resource "aws_appsync_function" "search_messages_function" {
  count = var.enable_opensearch ? 1 : 0
  
  api_id                   = aws_appsync_graphql_api.chat_api.id
  data_source              = aws_appsync_datasource.opensearch_datasource[0].name
  name                     = "SearchMessagesFunction"
  request_mapping_template = file("${path.module}/resolvers/searchMessages.request.vtl")
  response_mapping_template = file("${path.module}/resolvers/searchMessages.response.vtl")
}

# AppSync Resolvers
# Query: Get Messages
resource "aws_appsync_resolver" "get_messages" {
  api_id      = aws_appsync_graphql_api.chat_api.id
  field       = "getMessages"
  type        = "Query"
  data_source = aws_appsync_datasource.chat_messages_datasource.name

  request_template  = file("${path.module}/resolvers/getMessages.request.vtl")
  response_template = file("${path.module}/resolvers/getMessages.response.vtl")

  caching_config {
    caching_keys = ["$context.arguments.roomId", "$context.arguments.limit", "$context.arguments.nextToken"]
    ttl          = 60
  }
}

# Query: Get Rooms
resource "aws_appsync_resolver" "get_rooms" {
  api_id      = aws_appsync_graphql_api.chat_api.id
  field       = "getRooms"
  type        = "Query"
  data_source = aws_appsync_datasource.chat_resolver_datasource.name

  request_template  = file("${path.module}/resolvers/getRooms.request.vtl")
  response_template = file("${path.module}/resolvers/getRooms.response.vtl")

  caching_config {
    caching_keys = ["$context.arguments.userId"]
    ttl          = 300
  }
}

# Query: Search Messages
resource "aws_appsync_resolver" "search_messages" {
  count = var.enable_opensearch ? 1 : 0
  
  api_id      = aws_appsync_graphql_api.chat_api.id
  field       = "searchMessages"
  type        = "Query"
  data_source = aws_appsync_datasource.chat_resolver_datasource.name

  request_template  = file("${path.module}/resolvers/searchMessages.request.vtl")
  response_template = file("${path.module}/resolvers/searchMessages.response.vtl")
}

# Mutation: Send Message (Pipeline Resolver)
resource "aws_appsync_resolver" "send_message" {
  api_id = aws_appsync_graphql_api.chat_api.id
  field  = "sendMessage"
  type   = "Mutation"
  kind   = "PIPELINE"

  pipeline_config {
    functions = [
      aws_appsync_function.create_message_function.function_id
    ]
  }

  request_template  = file("${path.module}/resolvers/sendMessage.request.vtl")
  response_template = file("${path.module}/resolvers/sendMessage.response.vtl")
}

# Mutation: Create Room
resource "aws_appsync_resolver" "create_room" {
  api_id      = aws_appsync_graphql_api.chat_api.id
  field       = "createRoom"
  type        = "Mutation"
  data_source = aws_appsync_datasource.chat_resolver_datasource.name

  request_template  = file("${path.module}/resolvers/createRoom.request.vtl")
  response_template = file("${path.module}/resolvers/createRoom.response.vtl")
}

# Mutation: Update Presence
resource "aws_appsync_resolver" "update_presence" {
  api_id      = aws_appsync_graphql_api.chat_api.id
  field       = "updatePresence"
  type        = "Mutation"
  data_source = aws_appsync_datasource.user_presence_datasource.name

  request_template  = file("${path.module}/resolvers/updatePresence.request.vtl")
  response_template = file("${path.module}/resolvers/updatePresence.response.vtl")
}

# Subscription: On Message Added
resource "aws_appsync_resolver" "on_message_added" {
  api_id      = aws_appsync_graphql_api.chat_api.id
  field       = "onMessageAdded"
  type        = "Subscription"
  data_source = aws_appsync_datasource.chat_messages_datasource.name

  request_template  = file("${path.module}/resolvers/onMessageAdded.request.vtl")
  response_template = file("${path.module}/resolvers/onMessageAdded.response.vtl")
}

# Subscription: On Typing
resource "aws_appsync_resolver" "on_typing" {
  api_id      = aws_appsync_graphql_api.chat_api.id
  field       = "onTyping"
  type        = "Subscription"
  data_source = aws_appsync_datasource.user_presence_datasource.name

  request_template  = file("${path.module}/resolvers/onTyping.request.vtl")
  response_template = file("${path.module}/resolvers/onTyping.response.vtl")
}

# Subscription: On Presence Changed
resource "aws_appsync_resolver" "on_presence_changed" {
  api_id      = aws_appsync_graphql_api.chat_api.id
  field       = "onPresenceChanged"
  type        = "Subscription"
  data_source = aws_appsync_datasource.user_presence_datasource.name

  request_template  = file("${path.module}/resolvers/onPresenceChanged.request.vtl")
  response_template = file("${path.module}/resolvers/onPresenceChanged.response.vtl")
}

# API Key for development (optional)
resource "aws_appsync_api_key" "chat_api_key" {
  count = var.environment == "dev" ? 1 : 0
  
  api_id      = aws_appsync_graphql_api.chat_api.id
  description = "API Key for ${var.project_name}-${var.environment} chat development"
  expires     = "2024-12-31T23:59:59Z"
}

# CloudWatch Log Group for AppSync
resource "aws_cloudwatch_log_group" "appsync_logs" {
  name              = "/aws/appsync/apis/${aws_appsync_graphql_api.chat_api.id}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-appsync-logs"
    Type = "CloudWatchLogGroup"
    Module = "chat"
  })
}
