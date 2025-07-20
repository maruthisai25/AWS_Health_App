# =============================================================================
# RDS Aurora PostgreSQL Cluster for Marks Management
# =============================================================================

# DB Subnet Group
resource "aws_db_subnet_group" "marks_db_subnet_group" {
  name       = "${var.project_name}-${var.environment}-marks-db-subnet-group"
  subnet_ids = var.database_subnet_ids

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-db-subnet-group"
    Component = "marks"
    Purpose   = "database-networking"
  })
}

# DB Parameter Group for Aurora PostgreSQL
resource "aws_rds_cluster_parameter_group" "marks_cluster_pg" {
  family      = "aurora-postgresql15"
  name        = "${var.project_name}-${var.environment}-marks-cluster-pg"
  description = "Aurora PostgreSQL cluster parameter group for marks management"

  # Performance and connection parameters
  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,pg_hint_plan"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"  # Log queries taking more than 1 second
  }

  parameter {
    name  = "max_connections"
    value = "200"
  }

  parameter {
    name  = "work_mem"
    value = "16384"  # 16MB
  }

  parameter {
    name  = "maintenance_work_mem"
    value = "262144"  # 256MB
  }

  parameter {
    name  = "effective_cache_size"
    value = "1048576"  # 1GB
  }

  parameter {
    name  = "random_page_cost"
    value = "1.1"  # Optimized for SSD
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-cluster-pg"
    Component = "marks"
    Purpose   = "database-configuration"
  })
}

# DB Parameter Group for Aurora PostgreSQL Instances
resource "aws_db_parameter_group" "marks_instance_pg" {
  family      = "aurora-postgresql15"
  name        = "${var.project_name}-${var.environment}-marks-instance-pg"
  description = "Aurora PostgreSQL instance parameter group for marks management"

  # Instance-specific parameters
  parameter {
    name  = "log_rotation_age"
    value = "1440"  # 24 hours
  }

  parameter {
    name  = "log_rotation_size"
    value = "102400"  # 100MB
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-instance-pg"
    Component = "marks"
    Purpose   = "database-instance-configuration"
  })
}

# RDS Aurora PostgreSQL Cluster
resource "aws_rds_cluster" "marks_db" {
  cluster_identifier              = "${var.project_name}-${var.environment}-marks-cluster"
  engine                         = "aurora-postgresql"
  engine_version                 = var.db_engine_version
  database_name                  = var.db_name
  master_username                = var.db_username
  master_password                = var.db_password
  
  # Networking
  db_subnet_group_name           = aws_db_subnet_group.marks_db_subnet_group.name
  vpc_security_group_ids         = [aws_security_group.rds_sg.id]
  port                          = 5432
  
  # Backup and Maintenance
  backup_retention_period        = var.backup_retention_period
  preferred_backup_window        = var.backup_window
  preferred_maintenance_window   = var.maintenance_window
  copy_tags_to_snapshot         = true
  
  # Security
  storage_encrypted             = true
  kms_key_id                   = var.kms_key_arn != "" ? var.kms_key_arn : null
  
  # Parameter Groups
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.marks_cluster_pg.name
  
  # Snapshot Configuration
  skip_final_snapshot           = var.skip_final_snapshot
  final_snapshot_identifier     = var.final_snapshot_identifier != "" ? var.final_snapshot_identifier : "${var.project_name}-${var.environment}-marks-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  # Deletion Protection
  deletion_protection           = var.environment == "prod" ? true : false
  
  # Logging
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  # Apply changes immediately in development
  apply_immediately             = var.environment == "dev" ? true : false

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-cluster"
    Component = "marks"
    Purpose   = "database-cluster"
  })

  lifecycle {
    ignore_changes = [master_password]
  }
}

# RDS Aurora PostgreSQL Cluster Instances
resource "aws_rds_cluster_instance" "marks_db_instances" {
  count              = var.enable_multi_az ? 2 : 1
  identifier         = "${var.project_name}-${var.environment}-marks-instance-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.marks_db.id
  instance_class     = var.db_instance_class
  engine             = aws_rds_cluster.marks_db.engine
  engine_version     = aws_rds_cluster.marks_db.engine_version

  # Parameter Group
  db_parameter_group_name = aws_db_parameter_group.marks_instance_pg.name

  # Performance Insights
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_retention_period = var.performance_insights_retention_period
  performance_insights_kms_key_id      = var.kms_key_arn != "" ? var.kms_key_arn : null

  # Monitoring
  monitoring_interval = var.enable_enhanced_monitoring ? var.monitoring_interval : 0
  monitoring_role_arn = var.enable_enhanced_monitoring ? aws_iam_role.rds_enhanced_monitoring[0].arn : null

  # Apply changes immediately in development
  apply_immediately = var.environment == "dev" ? true : false

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-instance-${count.index + 1}"
    Component = "marks"
    Purpose   = "database-instance"
  })
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.enable_enhanced_monitoring ? 1 : 0
  name  = "${var.project_name}-${var.environment}-rds-enhanced-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-rds-enhanced-monitoring-role"
    Component = "marks"
    Purpose   = "database-monitoring"
  })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count      = var.enable_enhanced_monitoring ? 1 : 0
  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Log Group for PostgreSQL logs
resource "aws_cloudwatch_log_group" "postgresql_logs" {
  name              = "/aws/rds/cluster/${aws_rds_cluster.marks_db.cluster_identifier}/postgresql"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-postgresql-logs"
    Component = "marks"
    Purpose   = "database-logging"
  })
}

# RDS Proxy for Connection Pooling (Optional)
resource "aws_db_proxy" "marks_proxy" {
  count                  = var.environment == "prod" ? 1 : 0
  name                   = "${var.project_name}-${var.environment}-marks-proxy"
  engine_family         = "POSTGRESQL"
  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.db_credentials.arn
  }
  role_arn               = aws_iam_role.proxy_role[0].arn
  vpc_subnet_ids         = var.database_subnet_ids
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  require_tls            = true
  idle_client_timeout    = 1800  # 30 minutes

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-proxy"
    Component = "marks"
    Purpose   = "database-proxy"
  })
}

# RDS Proxy Target
resource "aws_db_proxy_default_target_group" "marks_proxy_target" {
  count          = var.environment == "prod" ? 1 : 0
  db_proxy_name  = aws_db_proxy.marks_proxy[0].name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "marks_proxy_target" {
  count                = var.environment == "prod" ? 1 : 0
  db_cluster_identifier = aws_rds_cluster.marks_db.cluster_identifier
  db_proxy_name        = aws_db_proxy.marks_proxy[0].name
  target_group_name    = aws_db_proxy_default_target_group.marks_proxy_target[0].name
}

# Secrets Manager for Database Credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-${var.environment}-marks-db-credentials"
  description             = "Database credentials for marks management system"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-db-credentials"
    Component = "marks"
    Purpose   = "database-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = "postgres"
    host     = aws_rds_cluster.marks_db.endpoint
    port     = aws_rds_cluster.marks_db.port
    dbname   = aws_rds_cluster.marks_db.database_name
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# IAM Role for RDS Proxy
resource "aws_iam_role" "proxy_role" {
  count = var.environment == "prod" ? 1 : 0
  name  = "${var.project_name}-${var.environment}-rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-rds-proxy-role"
    Component = "marks"
    Purpose   = "database-proxy-role"
  })
}

resource "aws_iam_role_policy" "proxy_policy" {
  count = var.environment == "prod" ? 1 : 0
  name  = "${var.project_name}-${var.environment}-rds-proxy-policy"
  role  = aws_iam_role.proxy_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.kms_key_arn != "" ? var.kms_key_arn : "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# RDS instance for marks database