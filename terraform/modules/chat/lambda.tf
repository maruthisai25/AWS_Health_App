# Lambda Functions for Chat System

# Lambda Execution Role
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-${var.environment}-chat-lambda-execution-role"

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

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chat-lambda-execution-role"
    Type = "IAMRole"
    Module = "chat"
  })
}

# Lambda Execution Policy
resource "aws_iam_role_policy" "lambda_execution_policy" {
  name = "${var.project_name}-${var.environment}-chat-lambda-execution-policy"
  role = aws_iam_role.lambda_execution_role.id

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
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.chat_messages.arn,
          aws_dynamodb_table.chat_rooms.arn,
          aws_dynamodb_table.room_members.arn,
          aws_dynamodb_table.user_presence.arn,
          "${aws_dynamodb_table.chat_messages.arn}/index/*",
          "${aws_dynamodb_table.chat_rooms.arn}/index/*",
          "${aws_dynamodb_table.room_members.arn}/index/*",
          "${aws_dynamodb_table.user_presence.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpDelete",
          "es:ESHttpHead"
        ]
        Resource = var.enable_opensearch ? "${aws_opensearch_domain.chat_search[0].arn}/*" : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:GetUser",
          "cognito-idp:AdminGetUser",
          "cognito-idp:ListUsers"
        ]
        Resource = "arn:aws:cognito-idp:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:userpool/${var.user_pool_id}"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AttachNetworkInterface",
          "ec2:DetachNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = [
          var.enable_dynamodb_encryption ? aws_kms_key.chat_encryption_key[0].arn : "",
          var.enable_opensearch ? aws_kms_key.opensearch_encryption_key[0].arn : ""
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda VPC Policy
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Security Group for Lambda Functions
resource "aws_security_group" "lambda_sg" {
  name_prefix = "${var.project_name}-${var.environment}-chat-lambda-"
  vpc_id      = var.vpc_id
  description = "Security group for chat Lambda functions"

  # Allow HTTPS outbound for API calls
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound"
  }

  # Allow HTTP outbound for package downloads
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP outbound"
  }

  # Allow DNS
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS outbound"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chat-lambda-sg"
    Type = "SecurityGroup"
    Module = "chat"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Lambda Function: Chat Resolver
resource "aws_lambda_function" "chat_resolver" {
  filename         = data.archive_file.chat_resolver_zip.output_path
  function_name    = "${var.project_name}-${var.environment}-chat-resolver"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  source_code_hash = data.archive_file.chat_resolver_zip.output_base64sha256

  reserved_concurrent_executions = var.lambda_reserved_concurrency

  # VPC Configuration
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  # Environment Variables
  environment {
    variables = {
      CHAT_MESSAGES_TABLE    = aws_dynamodb_table.chat_messages.name
      CHAT_ROOMS_TABLE       = aws_dynamodb_table.chat_rooms.name
      ROOM_MEMBERS_TABLE     = aws_dynamodb_table.room_members.name
      USER_PRESENCE_TABLE    = aws_dynamodb_table.user_presence.name
      OPENSEARCH_ENDPOINT    = var.enable_opensearch ? aws_opensearch_domain.chat_search[0].endpoint : ""
      USER_POOL_ID          = var.user_pool_id
      AWS_REGION            = data.aws_region.current.name
      LOG_LEVEL             = var.environment == "dev" ? "DEBUG" : "INFO"
      MAX_MESSAGE_LENGTH    = var.max_message_length
      MAX_ROOM_MEMBERS      = var.max_room_members
      TYPING_TIMEOUT        = var.typing_indicator_timeout
      PRESENCE_TIMEOUT      = var.presence_timeout
    }
  }

  # Dead letter queue configuration
  dead_letter_config {
    target_arn = aws_sqs_queue.chat_dlq.arn
  }

  # X-Ray tracing
  tracing_config {
    mode = "Active"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chat-resolver"
    Type = "Lambda"
    Module = "chat"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc_execution,
    aws_cloudwatch_log_group.chat_resolver_logs
  ]
}

# Lambda Function: Message Processor (for DynamoDB Streams)
resource "aws_lambda_function" "message_processor" {
  filename         = data.archive_file.message_processor_zip.output_path
  function_name    = "${var.project_name}-${var.environment}-message-processor"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  source_code_hash = data.archive_file.message_processor_zip.output_base64sha256

  reserved_concurrent_executions = var.lambda_reserved_concurrency

  # VPC Configuration
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  # Environment Variables
  environment {
    variables = {
      OPENSEARCH_ENDPOINT = var.enable_opensearch ? aws_opensearch_domain.chat_search[0].endpoint : ""
      AWS_REGION         = data.aws_region.current.name
      LOG_LEVEL          = var.environment == "dev" ? "DEBUG" : "INFO"
    }
  }

  # Dead letter queue configuration
  dead_letter_config {
    target_arn = aws_sqs_queue.message_processor_dlq.arn
  }

  # X-Ray tracing
  tracing_config {
    mode = "Active"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-message-processor"
    Type = "Lambda"
    Module = "chat"
  })

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc_execution,
    aws_cloudwatch_log_group.message_processor_logs
  ]
}

# Lambda Function: Auth Resolver (for AppSync Lambda authorization)
resource "aws_lambda_function" "auth_resolver" {
  filename         = data.archive_file.auth_resolver_zip.output_path
  function_name    = "${var.project_name}-${var.environment}-chat-auth-resolver"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = "index.handler"
  runtime         = var.lambda_runtime
  timeout         = 10
  memory_size     = 128
  source_code_hash = data.archive_file.auth_resolver_zip.output_base64sha256

  # Environment Variables
  environment {
    variables = {
      USER_POOL_ID = var.user_pool_id
      AWS_REGION   = data.aws_region.current.name
      LOG_LEVEL    = var.environment == "dev" ? "DEBUG" : "INFO"
    }
  }

  # X-Ray tracing
  tracing_config {
    mode = "Active"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chat-auth-resolver"
    Type = "Lambda"
    Module = "chat"
  })

  depends_on = [
    aws_cloudwatch_log_group.auth_resolver_logs
  ]
}

# DynamoDB Stream Event Source Mapping
resource "aws_lambda_event_source_mapping" "chat_messages_stream" {
  count = var.enable_opensearch ? 1 : 0
  
  event_source_arn  = aws_dynamodb_table.chat_messages.stream_arn
  function_name     = aws_lambda_function.message_processor.arn
  starting_position = "LATEST"
  batch_size        = 10
  
  # Error handling
  maximum_batching_window_in_seconds = 5
  maximum_record_age_in_seconds      = 3600
  maximum_retry_attempts             = 3
  parallelization_factor             = 2
  
  # Destination for failed records
  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.message_processor_dlq.arn
    }
  }

  # Filter criteria for specific record types
  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName = ["INSERT", "MODIFY"]
      })
    }
  }
}

# AppSync Service Role
resource "aws_iam_role" "appsync_service_role" {
  name = "${var.project_name}-${var.environment}-appsync-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-appsync-service-role"
    Type = "IAMRole"
    Module = "chat"
  })
}

# AppSync Service Policy
resource "aws_iam_role_policy" "appsync_service_policy" {
  name = "${var.project_name}-${var.environment}-appsync-service-policy"
  role = aws_iam_role.appsync_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.chat_messages.arn,
          aws_dynamodb_table.chat_rooms.arn,
          aws_dynamodb_table.room_members.arn,
          aws_dynamodb_table.user_presence.arn,
          "${aws_dynamodb_table.chat_messages.arn}/index/*",
          "${aws_dynamodb_table.chat_rooms.arn}/index/*",
          "${aws_dynamodb_table.room_members.arn}/index/*",
          "${aws_dynamodb_table.user_presence.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.chat_resolver.arn,
          aws_lambda_function.auth_resolver.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpDelete",
          "es:ESHttpHead"
        ]
        Resource = var.enable_opensearch ? "${aws_opensearch_domain.chat_search[0].arn}/*" : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

# Lambda Permissions for AppSync
resource "aws_lambda_permission" "appsync_chat_resolver" {
  statement_id  = "AllowExecutionFromAppSync"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chat_resolver.function_name
  principal     = "appsync.amazonaws.com"
  source_arn    = "${aws_appsync_graphql_api.chat_api.arn}/*"
}

resource "aws_lambda_permission" "appsync_auth_resolver" {
  statement_id  = "AllowExecutionFromAppSync"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_resolver.function_name
  principal     = "appsync.amazonaws.com"
  source_arn    = aws_appsync_graphql_api.chat_api.arn
}

# SQS Dead Letter Queues
resource "aws_sqs_queue" "chat_dlq" {
  name                      = "${var.project_name}-${var.environment}-chat-dlq"
  message_retention_seconds = 1209600 # 14 days
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chat-dlq"
    Type = "SQS"
    Module = "chat"
  })
}

resource "aws_sqs_queue" "message_processor_dlq" {
  name                      = "${var.project_name}-${var.environment}-message-processor-dlq"
  message_retention_seconds = 1209600 # 14 days
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-message-processor-dlq"
    Type = "SQS"
    Module = "chat"
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "chat_resolver_logs" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-chat-resolver"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chat-resolver-logs"
    Type = "CloudWatchLogGroup"
    Module = "chat"
  })
}

resource "aws_cloudwatch_log_group" "message_processor_logs" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-message-processor"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-message-processor-logs"
    Type = "CloudWatchLogGroup"
    Module = "chat"
  })
}

resource "aws_cloudwatch_log_group" "auth_resolver_logs" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-chat-auth-resolver"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chat-auth-resolver-logs"
    Type = "CloudWatchLogGroup"
    Module = "chat"
  })
}

# Lambda Function Aliases for Blue/Green Deployments
resource "aws_lambda_alias" "chat_resolver_live" {
  name             = "live"
  description      = "Live alias for chat resolver"
  function_name    = aws_lambda_function.chat_resolver.function_name
  function_version = "$LATEST"
}

resource "aws_lambda_alias" "message_processor_live" {
  name             = "live"
  description      = "Live alias for message processor"
  function_name    = aws_lambda_function.message_processor.function_name
  function_version = "$LATEST"
}

# Data sources for Lambda zip files
data "archive_file" "chat_resolver_zip" {
  type        = "zip"
  output_path = "${path.module}/../../applications/lambda-functions/chat-resolver.zip"
  source_dir  = "${path.module}/../../applications/lambda-functions/chat-resolver"
}

data "archive_file" "message_processor_zip" {
  type        = "zip"
  output_path = "${path.module}/../../applications/lambda-functions/message-processor.zip"
  source_dir  = "${path.module}/../../applications/lambda-functions/message-processor"
}

data "archive_file" "auth_resolver_zip" {
  type        = "zip"
  output_path = "${path.module}/../../applications/lambda-functions/chat-auth-resolver.zip"
  source_dir  = "${path.module}/../../applications/lambda-functions/chat-auth-resolver"
}
