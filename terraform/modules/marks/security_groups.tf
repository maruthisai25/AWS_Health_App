# =============================================================================
# Security Groups for Marks Management System
# =============================================================================

# Application Load Balancer Security Group
resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  vpc_id      = var.vpc_id
  description = "Security group for Application Load Balancer"

  # HTTP inbound
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "HTTP access from allowed CIDR blocks"
  }

  # HTTPS inbound
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "HTTPS access from allowed CIDR blocks"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-alb-sg"
    Component = "marks"
    Purpose   = "load-balancer-security"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 Instances Security Group
resource "aws_security_group" "ec2_sg" {
  name_prefix = "${var.project_name}-${var.environment}-ec2-"
  vpc_id      = var.vpc_id
  description = "Security group for EC2 instances running marks application"

  # Application port from ALB
  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Application port from ALB"
  }

  # SSH access (optional, only if key pair is provided)
  dynamic "ingress" {
    for_each = var.ec2_key_pair_name != "" ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]  # Only from VPC
      description = "SSH access from VPC"
    }
  }

  # Health check from ALB
  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Health check from ALB"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-ec2-sg"
    Component = "marks"
    Purpose   = "application-server-security"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Security Group
resource "aws_security_group" "rds_sg" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  vpc_id      = var.vpc_id
  description = "Security group for RDS Aurora PostgreSQL cluster"

  # PostgreSQL port from EC2 instances
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
    description     = "PostgreSQL access from EC2 instances"
  }

  # PostgreSQL port from Lambda functions (if needed)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
    description = "PostgreSQL access from VPC (for Lambda functions)"
  }

  # No outbound rules needed for RDS
  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-rds-sg"
    Component = "marks"
    Purpose   = "database-security"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Additional Security Group Rules for Enhanced Security

# Rule to allow EC2 instances to communicate with each other (for clustering if needed)
resource "aws_security_group_rule" "ec2_internal_communication" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2_sg.id
  security_group_id        = aws_security_group.ec2_sg.id
  description              = "Allow EC2 instances to communicate with each other"
}

# Rule to allow health checks from ALB on custom health check port (if different)
resource "aws_security_group_rule" "alb_health_check" {
  count                    = var.app_port != 80 ? 1 : 0
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id        = aws_security_group.ec2_sg.id
  description              = "Health check from ALB on port 80"
}

# Data source to get VPC information
data "aws_vpc" "main" {
  id = var.vpc_id
}

# Network ACL for additional security (optional)
resource "aws_network_acl" "marks_nacl" {
  vpc_id     = var.vpc_id
  subnet_ids = concat(var.private_subnet_ids, var.database_subnet_ids)

  # Allow HTTP inbound
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    from_port  = 80
    to_port    = 80
    cidr_block = "0.0.0.0/0"
  }

  # Allow HTTPS inbound
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    from_port  = 443
    to_port    = 443
    cidr_block = "0.0.0.0/0"
  }

  # Allow application port inbound
  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    from_port  = var.app_port
    to_port    = var.app_port
    cidr_block = data.aws_vpc.main.cidr_block
  }

  # Allow PostgreSQL inbound
  ingress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    from_port  = 5432
    to_port    = 5432
    cidr_block = data.aws_vpc.main.cidr_block
  }

  # Allow SSH inbound (if key pair is provided)
  dynamic "ingress" {
    for_each = var.ec2_key_pair_name != "" ? [1] : []
    content {
      rule_no    = 140
      protocol   = "tcp"
      action     = "allow"
      from_port  = 22
      to_port    = 22
      cidr_block = data.aws_vpc.main.cidr_block
    }
  }

  # Allow ephemeral ports inbound (for return traffic)
  ingress {
    rule_no    = 200
    protocol   = "tcp"
    action     = "allow"
    from_port  = 1024
    to_port    = 65535
    cidr_block = "0.0.0.0/0"
  }

  # Allow all outbound
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    from_port  = 0
    to_port    = 0
    cidr_block = "0.0.0.0/0"
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-nacl"
    Component = "marks"
    Purpose   = "network-security"
  })
}

# Security Group for Bastion Host (optional)
resource "aws_security_group" "bastion_sg" {
  count       = var.ec2_key_pair_name != "" ? 1 : 0
  name_prefix = "${var.project_name}-${var.environment}-bastion-"
  vpc_id      = var.vpc_id
  description = "Security group for bastion host"

  # SSH inbound from allowed CIDR blocks
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "SSH access from allowed CIDR blocks"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-bastion-sg"
    Component = "marks"
    Purpose   = "bastion-security"
  })

  lifecycle {
    create_before_destroy = true
  }
}