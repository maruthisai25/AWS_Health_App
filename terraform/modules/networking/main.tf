# =============================================================================
# AWS Education Platform - Networking Module
# =============================================================================
#
# This module creates the core networking infrastructure including:
# - VPC with DNS support
# - Public and private subnets across multiple AZs
# - Internet Gateway and NAT Gateways
# - Route tables and associations
# - Security groups for different tiers
# - VPC Flow Logs for security monitoring
# - Network ACLs for additional security
#
# The module is designed to be reusable across environments with
# configurable parameters for cost optimization and security.
# =============================================================================

# =============================================================================
# Data Sources
# =============================================================================

# Get available availability zones in the current region
data "aws_availability_zones" "available" {
  state = "available"
  
  # Exclude zones that might have limited capacity or higher costs
  exclude_names = ["us-west-1c"]
}

# Get current AWS caller identity for resource naming
data "aws_caller_identity" "current" {}

# Get current region information
data "aws_region" "current" {}

# =============================================================================
# Local Values and Calculations
# =============================================================================

locals {
  # Use specified number of AZs or all available (max 3 for cost optimization)
  azs = slice(
    data.aws_availability_zones.available.names,
    0,
    min(var.availability_zones_count, length(data.aws_availability_zones.available.names))
  )
  
  # Number of availability zones to use
  az_count = length(local.azs)
  
  # Common naming prefix
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Common tags for all resources
  common_tags = merge(
    var.common_tags,
    {
      Module = "networking"
      Name   = "${local.name_prefix}-networking"
    }
  )
  
  # Calculate subnet CIDRs
  # Public subnets: 10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24
  # Private subnets: 10.0.10.0/24, 10.0.11.0/24, 10.0.12.0/24
  # Database subnets: 10.0.20.0/24, 10.0.21.0/24, 10.0.22.0/24
  public_subnet_cidrs   = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnet_cidrs  = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 10)]
  database_subnet_cidrs = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 20)]
}

# =============================================================================
# VPC and Core Networking
# =============================================================================

# Main VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  
  # Enable DNS support and hostnames for service discovery
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  
  # Enable IPv6 if requested (optional)
  assign_generated_ipv6_cidr_block = var.enable_ipv6
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
    Type = "vpc"
  })
}

# Internet Gateway for public subnet internet access
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
    Type = "internet-gateway"
  })
}

# =============================================================================
# Public Subnets
# =============================================================================

# Public subnets for load balancers, NAT gateways, and bastion hosts
resource "aws_subnet" "public" {
  count = local.az_count
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]
  
  # Auto-assign public IPs for instances in public subnets
  map_public_ip_on_launch = true
  
  tags = merge(local.common_tags, var.subnet_tags, {
    Name = "${local.name_prefix}-public-${substr(local.azs[count.index], -1, 1)}"
    Type = "public"
    Tier = "public"
    AZ   = local.azs[count.index]
  })
}

# =============================================================================
# Private Subnets
# =============================================================================

# Private subnets for application servers
resource "aws_subnet" "private" {
  count = local.az_count
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]
  
  tags = merge(local.common_tags, var.subnet_tags, {
    Name = "${local.name_prefix}-private-${substr(local.azs[count.index], -1, 1)}"
    Type = "private"
    Tier = "application"
    AZ   = local.azs[count.index]
  })
}

# =============================================================================
# Database Subnets
# =============================================================================

# Database subnets for RDS and other data stores
resource "aws_subnet" "database" {
  count = local.az_count
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.database_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]
  
  tags = merge(local.common_tags, var.subnet_tags, {
    Name = "${local.name_prefix}-database-${substr(local.azs[count.index], -1, 1)}"
    Type = "database"
    Tier = "database"
    AZ   = local.azs[count.index]
  })
}

# Database subnet group for RDS
resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnet-group"
    Type = "db-subnet-group"
  })
}
# =============================================================================
# NAT Gateways and Elastic IPs
# =============================================================================

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0
  
  domain = "vpc"
  
  # Ensure Internet Gateway exists before creating EIP
  depends_on = [aws_internet_gateway.main]
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eip-nat-${count.index + 1}"
    Type = "elastic-ip"
  })
}

# NAT Gateways for outbound internet access from private subnets
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0
  
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${count.index + 1}"
    Type = "nat-gateway"
    AZ   = local.azs[count.index]
  })
  
  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# Route Tables
# =============================================================================

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rt-public"
    Type = "route-table"
    Tier = "public"
  })
}

# Route table for private subnets (one per AZ if multiple NAT gateways)
resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 1
  
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.common_tags, {
    Name = var.single_nat_gateway ? "${local.name_prefix}-rt-private" : "${local.name_prefix}-rt-private-${count.index + 1}"
    Type = "route-table"
    Tier = "private"
  })
}

# Route table for database subnets
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rt-database"
    Type = "route-table"
    Tier = "database"
  })
}

# =============================================================================
# Routes
# =============================================================================

# Route to Internet Gateway for public subnets
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
  
  timeouts {
    create = "5m"
  }
}

# Routes to NAT Gateway for private subnets
resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0
  
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
  
  timeouts {
    create = "5m"
  }
}

# =============================================================================
# Route Table Associations
# =============================================================================

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = local.az_count
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with appropriate private route tables
resource "aws_route_table_association" "private" {
  count = local.az_count
  
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# Associate database subnets with database route table
resource "aws_route_table_association" "database" {
  count = local.az_count
  
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# =============================================================================
# Security Groups
# =============================================================================

# Default security group for VPC (restrictive)
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  
  # Remove all default rules
  ingress = []
  egress  = []
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sg-default"
    Type = "security-group"
  })
}

# Security group for web tier (load balancers)
resource "aws_security_group" "web" {
  name_prefix = "${local.name_prefix}-sg-web-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for web tier load balancers"
  
  # HTTP access from internet
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # HTTPS access from internet
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sg-web"
    Type = "security-group"
    Tier = "web"
  })
  
  lifecycle {
    create_before_destroy = true
  }
}

# Security group for application tier
resource "aws_security_group" "app" {
  name_prefix = "${local.name_prefix}-sg-app-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for application tier"
  
  # HTTP access from web tier
  ingress {
    description     = "HTTP from web tier"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }
  
  # SSH access from bastion (will be created later)
  ingress {
    description = "SSH from bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sg-app"
    Type = "security-group"
    Tier = "application"
  })
  
  lifecycle {
    create_before_destroy = true
  }
}

# Security group for database tier
resource "aws_security_group" "database" {
  name_prefix = "${local.name_prefix}-sg-db-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for database tier"
  
  # PostgreSQL access from application tier
  ingress {
    description     = "PostgreSQL from app tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  
  # MySQL access from application tier (if needed)
  ingress {
    description     = "MySQL from app tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  
  # No outbound rules (database should not initiate connections)
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sg-database"
    Type = "security-group"
    Tier = "database"
  })
  
  lifecycle {
    create_before_destroy = true
  }
}
# =============================================================================
# VPC Flow Logs
# =============================================================================

# IAM role for VPC Flow Logs
resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  
  name = "${local.name_prefix}-vpc-flow-logs-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc-flow-logs-role"
    Type = "iam-role"
  })
}

# IAM policy for VPC Flow Logs
resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  
  name = "${local.name_prefix}-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0
  
  name              = "/aws/vpc/flowlogs/${local.name_prefix}"
  retention_in_days = var.flow_logs_retention_days
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc-flow-logs"
    Type = "cloudwatch-log-group"
  })
}

# VPC Flow Logs
resource "aws_flow_log" "vpc" {
  count = var.enable_flow_logs ? 1 : 0
  
  iam_role_arn    = aws_iam_role.flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc-flow-logs"
    Type = "vpc-flow-logs"
  })
}

# =============================================================================
# Network ACLs (Additional Security Layer)
# =============================================================================

# Network ACL for public subnets
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id
  
  # Allow inbound HTTP
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  
  # Allow inbound HTTPS
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  
  # Allow inbound SSH from specific CIDR (replace with your IP range)
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"  # Restrict this in production
    from_port  = 22
    to_port    = 22
  }
  
  # Allow inbound ephemeral ports
  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  
  # Allow all outbound traffic
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nacl-public"
    Type = "network-acl"
    Tier = "public"
  })
}

# Network ACL for private subnets
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id
  
  # Allow inbound from VPC
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }
  
  # Allow inbound ephemeral ports for responses
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  
  # Allow all outbound traffic
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nacl-private"
    Type = "network-acl"
    Tier = "private"
  })
}

# Network ACL for database subnets
resource "aws_network_acl" "database" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.database[*].id
  
  # Allow inbound database traffic from private subnets
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 3306
    to_port    = 3306
  }
  
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 5432
    to_port    = 5432
  }
  
  # Allow outbound to VPC for responses
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 1024
    to_port    = 65535
  }
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nacl-database"
    Type = "network-acl"
    Tier = "database"
  })
}

# =============================================================================
# VPC Endpoints (Optional - for AWS Services)
# =============================================================================

# S3 VPC Endpoint for cost optimization
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_vpc_endpoints ? 1 : 0
  
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(aws_route_table.private[*].id, [aws_route_table.database.id])
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpce-s3"
    Type = "vpc-endpoint"
  })
}

# DynamoDB VPC Endpoint
resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_vpc_endpoints ? 1 : 0
  
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(aws_route_table.private[*].id, [aws_route_table.database.id])
  
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpce-dynamodb"
    Type = "vpc-endpoint"
  })
}
