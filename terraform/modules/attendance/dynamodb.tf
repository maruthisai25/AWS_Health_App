# =============================================================================
# DynamoDB Tables for Attendance System
# =============================================================================

# Attendance Records Table
resource "aws_dynamodb_table" "attendance" {
  name           = "${var.project_name}-${var.environment}-attendance"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "attendance_id"
  range_key      = "timestamp"

  # Provisioned capacity (only used if billing_mode is PROVISIONED)
  read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
  write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null

  # Attributes
  attribute {
    name = "attendance_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "class_id"
    type = "S"
  }

  attribute {
    name = "date"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  # Global Secondary Indexes
  global_secondary_index {
    name            = "UserDateIndex"
    hash_key        = "user_id"
    range_key       = "date"
    projection_type = "ALL"
    
    read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
    write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  }

  global_secondary_index {
    name            = "ClassDateIndex"
    hash_key        = "class_id"
    range_key       = "date"
    projection_type = "ALL"
    
    read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
    write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  }

  global_secondary_index {
    name            = "StatusDateIndex"
    hash_key        = "status"
    range_key       = "date"
    projection_type = "ALL"
    
    read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
    write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  }

  # TTL for automatic cleanup of old records (optional)
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

  # Tags
  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-attendance"
    Component   = "attendance"
    Purpose     = "attendance-records"
  })
}

# Classes Table
resource "aws_dynamodb_table" "classes" {
  name           = "${var.project_name}-${var.environment}-classes"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "class_id"

  # Provisioned capacity (only used if billing_mode is PROVISIONED)
  read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
  write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null

  # Attributes
  attribute {
    name = "class_id"
    type = "S"
  }

  attribute {
    name = "instructor_id"
    type = "S"
  }

  attribute {
    name = "course_code"
    type = "S"
  }

  attribute {
    name = "date"
    type = "S"
  }

  # Global Secondary Indexes
  global_secondary_index {
    name            = "InstructorIndex"
    hash_key        = "instructor_id"
    range_key       = "date"
    projection_type = "ALL"
    
    read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
    write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  }

  global_secondary_index {
    name            = "CourseIndex"
    hash_key        = "course_code"
    range_key       = "date"
    projection_type = "ALL"
    
    read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
    write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = var.enable_dynamodb_encryption
  }

  # Tags
  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-classes"
    Component   = "attendance"
    Purpose     = "class-management"
  })
}

# Auto Scaling for Provisioned Tables (if enabled)
resource "aws_appautoscaling_target" "attendance_read" {
  count              = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0
  max_capacity       = 100
  min_capacity       = var.dynamodb_read_capacity
  resource_id        = "table/${aws_dynamodb_table.attendance.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_target" "attendance_write" {
  count              = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0
  max_capacity       = 100
  min_capacity       = var.dynamodb_write_capacity
  resource_id        = "table/${aws_dynamodb_table.attendance.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "attendance_read_policy" {
  count              = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0
  name               = "${var.project_name}-${var.environment}-attendance-read-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.attendance_read[0].resource_id
  scalable_dimension = aws_appautoscaling_target.attendance_read[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.attendance_read[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_appautoscaling_policy" "attendance_write_policy" {
  count              = var.dynamodb_billing_mode == "PROVISIONED" ? 1 : 0
  name               = "${var.project_name}-${var.environment}-attendance-write-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.attendance_write[0].resource_id
  scalable_dimension = aws_appautoscaling_target.attendance_write[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.attendance_write[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = 70.0
  }
}