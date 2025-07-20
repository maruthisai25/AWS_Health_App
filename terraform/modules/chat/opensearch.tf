# OpenSearch Domain for Chat Message Search

# OpenSearch Domain
resource "aws_opensearch_domain" "chat_search" {
  count = var.enable_opensearch ? 1 : 0
  
  domain_name    = "${var.project_name}-${var.environment}-chat-search"
  engine_version = var.opensearch_version

  cluster_config {
    instance_type            = var.opensearch_instance_type
    instance_count           = var.opensearch_instance_count
    dedicated_master_enabled = var.opensearch_instance_count > 2
    dedicated_master_type    = var.opensearch_instance_count > 2 ? "t3.small.search" : null
    dedicated_master_count   = var.opensearch_instance_count > 2 ? 3 : null
    zone_awareness_enabled   = var.opensearch_instance_count > 1
    
    dynamic "zone_awareness_config" {
      for_each = var.opensearch_instance_count > 1 ? [1] : []
      content {
        availability_zone_count = min(var.opensearch_instance_count, 3)
      }
    }
  }

  # VPC Configuration for security
  vpc_options {
    subnet_ids         = slice(var.private_subnet_ids, 0, min(length(var.private_subnet_ids), var.opensearch_instance_count > 1 ? 2 : 1))
    security_group_ids = [aws_security_group.opensearch_sg[0].id]
  }

  # EBS Configuration
  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = var.opensearch_ebs_volume_size
    throughput  = 125
    iops        = 3000
  }

  # Advanced options for performance
  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
    "indices.query.bool.max_clause_count"    = "10000"
    "indices.fielddata.cache.size"           = "40%"
  }

  # Access policy for Lambda functions and developers
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.lambda_execution_role.arn,
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          ]
        }
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpDelete",
          "es:ESHttpHead"
        ]
        Resource = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.project_name}-${var.environment}-chat-search/*"
      }
    ]
  })

  # Encryption at rest
  encrypt_at_rest {
    enabled    = true
    kms_key_id = aws_kms_key.opensearch_encryption_key[0].arn
  }

  # Node-to-node encryption
  node_to_node_encryption {
    enabled = true
  }

  # Domain endpoint options
  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  # Log publishing options
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_application_logs[0].arn
    log_type                 = "ES_APPLICATION_LOGS"
    enabled                  = true
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_search_logs[0].arn
    log_type                 = "SEARCH_SLOW_LOGS"
    enabled                  = true
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_index_logs[0].arn
    log_type                 = "INDEX_SLOW_LOGS"
    enabled                  = true
  }

  # Auto-tune for performance optimization
  auto_tune_options {
    desired_state       = "ENABLED"
    rollback_on_disable = "NO_ROLLBACK"
    
    maintenance_schedule {
      start_at                       = "2023-01-01T00:00:00Z"
      duration {
        value = "2"
        unit  = "HOURS"
      }
      cron_expression_for_recurrence = "cron(0 2 * * SUN *)"
    }
  }

  # Snapshot configuration
  snapshot_options {
    automated_snapshot_start_hour = 3
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-chat-search"
    Type = "OpenSearch"
    Module = "chat"
  })

  depends_on = [
    aws_cloudwatch_log_resource_policy.opensearch_policy
  ]
}

# Security Group for OpenSearch
resource "aws_security_group" "opensearch_sg" {
  count = var.enable_opensearch ? 1 : 0
  
  name_prefix = "${var.project_name}-${var.environment}-opensearch-"
  vpc_id      = var.vpc_id
  description = "Security group for OpenSearch domain"

  # Allow HTTPS from Lambda functions
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
    description     = "HTTPS from Lambda functions"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-opensearch-sg"
    Type = "SecurityGroup"
    Module = "chat"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# KMS Key for OpenSearch encryption
resource "aws_kms_key" "opensearch_encryption_key" {
  count = var.enable_opensearch ? 1 : 0
  
  description             = "KMS key for ${var.project_name}-${var.environment} OpenSearch encryption"
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
        Sid    = "Allow OpenSearch Service"
        Effect = "Allow"
        Principal = {
          Service = "es.amazonaws.com"
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
    Name = "${var.project_name}-${var.environment}-opensearch-encryption-key"
    Type = "KMS"
    Module = "chat"
  })
}

# KMS Key Alias for OpenSearch
resource "aws_kms_alias" "opensearch_encryption_key_alias" {
  count = var.enable_opensearch ? 1 : 0
  
  name          = "alias/${var.project_name}-${var.environment}-opensearch-encryption"
  target_key_id = aws_kms_key.opensearch_encryption_key[0].key_id
}

# CloudWatch Log Groups for OpenSearch
resource "aws_cloudwatch_log_group" "opensearch_application_logs" {
  count = var.enable_opensearch ? 1 : 0
  
  name              = "/aws/opensearch/domains/${var.project_name}-${var.environment}-chat-search/application-logs"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-opensearch-application-logs"
    Type = "CloudWatchLogGroup"
    Module = "chat"
  })
}

resource "aws_cloudwatch_log_group" "opensearch_search_logs" {
  count = var.enable_opensearch ? 1 : 0
  
  name              = "/aws/opensearch/domains/${var.project_name}-${var.environment}-chat-search/search-logs"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-opensearch-search-logs"
    Type = "CloudWatchLogGroup"
    Module = "chat"
  })
}

resource "aws_cloudwatch_log_group" "opensearch_index_logs" {
  count = var.enable_opensearch ? 1 : 0
  
  name              = "/aws/opensearch/domains/${var.project_name}-${var.environment}-chat-search/index-logs"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-opensearch-index-logs"
    Type = "CloudWatchLogGroup"
    Module = "chat"
  })
}

# CloudWatch Log Resource Policy for OpenSearch
resource "aws_cloudwatch_log_resource_policy" "opensearch_policy" {
  count = var.enable_opensearch ? 1 : 0
  
  policy_name = "${var.project_name}-${var.environment}-opensearch-log-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "es.amazonaws.com"
        }
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

# Data sources
data "aws_region" "current" {}
