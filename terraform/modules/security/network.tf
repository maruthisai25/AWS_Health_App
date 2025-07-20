# =============================================================================
# Network Security Configuration
# =============================================================================

# =============================================================================
# Network ACLs
# =============================================================================

# Public Network ACL
resource "aws_network_acl" "public" {
  count = var.enable_network_acls ? 1 : 0

  vpc_id     = var.vpc_id
  subnet_ids = var.public_subnet_ids

  # Inbound Rules
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "10.0.0.0/16"  # VPC CIDR
    from_port  = 22
    to_port    = 22
  }

  # Allow return traffic for outbound connections
  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound Rules
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "10.0.0.0/16"  # VPC CIDR
    from_port  = 0
    to_port    = 65535
  }

  # Allow return traffic for inbound connections
  egress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-public-nacl"
    Purpose     = "network-security"
    Tier        = "public"
    Module      = "security"
  })
}

# Private Network ACL
resource "aws_network_acl" "private" {
  count = var.enable_network_acls ? 1 : 0

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Inbound Rules
  # Allow traffic from public subnets
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.0.0/24"  # Public subnet 1
    from_port  = 0
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "10.0.1.0/24"  # Public subnet 2
    from_port  = 0
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "10.0.2.0/24"  # Public subnet 3
    from_port  = 0
    to_port    = 65535
  }

  # Allow inter-private subnet communication
  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "10.0.10.0/24"  # Private subnet 1
    from_port  = 0
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 140
    action     = "allow"
    cidr_block = "10.0.11.0/24"  # Private subnet 2
    from_port  = 0
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 150
    action     = "allow"
    cidr_block = "10.0.12.0/24"  # Private subnet 3
    from_port  = 0
    to_port    = 65535
  }

  # Allow return traffic for outbound connections
  ingress {
    protocol   = "tcp"
    rule_no    = 160
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound Rules
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "10.0.0.0/16"  # VPC CIDR
    from_port  = 0
    to_port    = 65535
  }

  # Allow return traffic for inbound connections
  egress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-private-nacl"
    Purpose     = "network-security"
    Tier        = "private"
    Module      = "security"
  })
}

# =============================================================================
# Security Groups for Enhanced Security
# =============================================================================

# Bastion Host Security Group (if needed)
resource "aws_security_group" "bastion" {
  count = var.enable_network_acls ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-bastion-"
  vpc_id      = var.vpc_id
  description = "Security group for bastion host"

  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ip_whitelist
  }

  egress {
    description = "SSH to private subnets"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  }

  egress {
    description = "HTTPS for updates"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP for updates"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-bastion-sg"
    Purpose     = "bastion-security"
    Module      = "security"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Database Security Group (enhanced)
resource "aws_security_group" "database_enhanced" {
  count = var.enable_network_acls ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-database-enhanced-"
  vpc_id      = var.vpc_id
  description = "Enhanced security group for database tier"

  ingress {
    description     = "PostgreSQL from application tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.application_enhanced[0].id]
  }

  # No egress rules - databases shouldn't initiate outbound connections

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-database-enhanced-sg"
    Purpose     = "database-security"
    Module      = "security"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Application Security Group (enhanced)
resource "aws_security_group" "application_enhanced" {
  count = var.enable_network_acls ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-application-enhanced-"
  vpc_id      = var.vpc_id
  description = "Enhanced security group for application tier"

  ingress {
    description     = "HTTP from load balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer_enhanced[0].id]
  }

  ingress {
    description     = "HTTPS from load balancer"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer_enhanced[0].id]
  }

  ingress {
    description     = "Custom app port from load balancer"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer_enhanced[0].id]
  }

  ingress {
    description     = "SSH from bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion[0].id]
  }

  egress {
    description = "HTTPS for external APIs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP for external APIs"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "Database access"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.database_enhanced[0].id]
  }

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-application-enhanced-sg"
    Purpose     = "application-security"
    Module      = "security"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Load Balancer Security Group (enhanced)
resource "aws_security_group" "load_balancer_enhanced" {
  count = var.enable_network_acls ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-load-balancer-enhanced-"
  vpc_id      = var.vpc_id
  description = "Enhanced security group for load balancer"

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "HTTP to application tier"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.application_enhanced[0].id]
  }

  egress {
    description     = "HTTPS to application tier"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.application_enhanced[0].id]
  }

  egress {
    description     = "Custom app port to application tier"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.application_enhanced[0].id]
  }

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-load-balancer-enhanced-sg"
    Purpose     = "load-balancer-security"
    Module      = "security"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# VPC Endpoint Security Groups
# =============================================================================

resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_network_acls ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-vpc-endpoints-"
  vpc_id      = var.vpc_id
  description = "Security group for VPC endpoints"

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = merge(var.tags, var.security_tags, {
    Name        = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
    Purpose     = "vpc-endpoint-security"
    Module      = "security"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Data Sources
# =============================================================================