# DynamoDB Tables for Chat System

# Chat Messages Table
resource "aws_dynamodb_table" "chat_messages" {
  name           = "${var.project_name}-${var.environment}-chat-messages"
  billing_mode   = var.dynamodb_billing_mode
  read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
  write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  hash_key       = "room_id"
  range_key      = "message_id"

  # GSI for user messages
  global_secondary_index {
    name     = "UserMessagesIndex"
    hash_key = "user_id"
    range_key = "timestamp"
    projection_type = "ALL"
    
    read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
    write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  }

  # GSI for timestamp-based queries
  global_secondary_index {
    name     = "TimestampIndex"
    hash_key = "room_id"
    range_key = "timestamp"
    projection_type = "ALL"
    
    read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
    write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  }

  # LSI for message types
  local_secondary_index {
    name               = "MessageTypeIndex"
    range_key          = "message_type"
    projection_type    = "ALL"
  }

  attribute {
    name = "room_id"
    type = "S"
  }

  attribute {
    name = "message_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "message_type"
    type = "S"
  }

  # TTL for automatic message cleanup
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = var.enable_dynamodb_encryption
  }

  # DynamoDB Streams for real-time updates
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chat-messages"
    Type = "DynamoDB"
    Module = "chat"
  })
}

# Chat Rooms Table
resource "aws_dynamodb_table" "chat_rooms" {
  name           = "${var.project_name}-${var.environment}-chat-rooms"
  billing_mode   = var.dynamodb_billing_mode
  read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
  write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  hash_key       = "room_id"

  # GSI for room types
  global_secondary_index {
    name     = "RoomTypeIndex"
    hash_key = "room_type"
    range_key = "created_at"
    projection_type = "ALL"
    
    read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
    write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  }

  attribute {
    name = "room_id"
    type = "S"
  }

  attribute {
    name = "room_type"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "N"
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = var.enable_dynamodb_encryption
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chat-rooms"
    Type = "DynamoDB"
    Module = "chat"
  })
}

# Room Members Table (separate table for room membership)
resource "aws_dynamodb_table" "room_members" {
  name           = "${var.project_name}-${var.environment}-room-members"
  billing_mode   = var.dynamodb_billing_mode
  read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
  write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  hash_key       = "room_id"
  range_key      = "user_id"

  # GSI for user rooms
  global_secondary_index {
    name     = "UserRoomsIndex"
    hash_key = "user_id"
    range_key = "joined_at"
    projection_type = "ALL"
    
    read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
    write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  }

  # GSI for room roles
  global_secondary_index {
    name     = "RoomRolesIndex"
    hash_key = "room_id"
    range_key = "role"
    projection_type = "ALL"
    
    read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
    write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  }

  attribute {
    name = "room_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "joined_at"
    type = "N"
  }

  attribute {
    name = "role"
    type = "S"
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = var.enable_dynamodb_encryption
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-room-members"
    Type = "DynamoDB"
    Module = "chat"
  })
}

# User Presence Table
resource "aws_dynamodb_table" "user_presence" {
  name           = "${var.project_name}-${var.environment}-user-presence"
  billing_mode   = var.dynamodb_billing_mode
  read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
  write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  hash_key       = "user_id"

  # GSI for room presence
  global_secondary_index {
    name     = "RoomPresenceIndex"
    hash_key = "room_id"
    range_key = "last_seen"
    projection_type = "ALL"
    
    read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
    write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  }

  # GSI for status-based queries
  global_secondary_index {
    name     = "StatusIndex"
    hash_key = "status"
    range_key = "last_seen"
    projection_type = "ALL"
    
    read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
    write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "room_id"
    type = "S"
  }

  attribute {
    name = "last_seen"
    type = "N"
  }

  attribute {
    name = "status"
    type = "S"
  }

  # TTL for automatic presence cleanup
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = var.enable_dynamodb_encryption
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-user-presence"
    Type = "DynamoDB"
    Module = "chat"
  })
}

# KMS Key for DynamoDB encryption
resource "aws_kms_key" "chat_encryption_key" {
  count = var.enable_dynamodb_encryption ? 1 : 0
  
  description             = "KMS key for ${var.project_name}-${var.environment} chat system encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow DynamoDB Service"
        Effect = "Allow"
        Principal = {
          Service = "dynamodb.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chat-encryption-key"
    Type = "KMS"
    Module = "chat"
  })
}

# KMS Key Alias
resource "aws_kms_alias" "chat_encryption_key_alias" {
  count = var.enable_dynamodb_encryption ? 1 : 0
  
  name          = "alias/${var.project_name}-${var.environment}-chat-encryption"
  target_key_id = aws_kms_key.chat_encryption_key[0].key_id
}

# DynamoDB Autoscaling for Production
resource "aws_appautoscaling_target" "chat_messages_read_target" {
  count = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0
  
  max_capacity       = 40
  min_capacity       = var.dynamodb_read_capacity
  resource_id        = "table/${aws_dynamodb_table.chat_messages.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "chat_messages_read_policy" {
  count = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0
  
  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.chat_messages_read_target[0].resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.chat_messages_read_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.chat_messages_read_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.chat_messages_read_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = 70
  }
}

resource "aws_appautoscaling_target" "chat_messages_write_target" {
  count = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0
  
  max_capacity       = 40
  min_capacity       = var.dynamodb_write_capacity
  resource_id        = "table/${aws_dynamodb_table.chat_messages.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "chat_messages_write_policy" {
  count = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0
  
  name               = "DynamoDBWriteCapacityUtilization:${aws_appautoscaling_target.chat_messages_write_target[0].resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.chat_messages_write_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.chat_messages_write_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.chat_messages_write_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = 70
  }
}
