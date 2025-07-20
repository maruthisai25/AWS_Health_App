# =============================================================================
# AWS Education Platform - Networking Module Outputs
# =============================================================================
#
# This file defines all outputs from the networking module that can be
# used by other modules or for reference in the root configuration.
#
# Outputs are organized by resource type for better maintainability.
# =============================================================================

# =============================================================================
# VPC Outputs
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.main.arn
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_instance_tenancy" {
  description = "Tenancy of instances spin up within VPC"
  value       = aws_vpc.main.instance_tenancy
}

output "vpc_enable_dns_support" {
  description = "Whether or not the VPC has DNS support"
  value       = aws_vpc.main.enable_dns_support
}

output "vpc_enable_dns_hostnames" {
  description = "Whether or not the VPC has DNS hostname support"
  value       = aws_vpc.main.enable_dns_hostnames
}

output "vpc_main_route_table_id" {
  description = "ID of the main route table associated with this VPC"
  value       = aws_vpc.main.main_route_table_id
}

output "vpc_default_network_acl_id" {
  description = "ID of the default network ACL"
  value       = aws_vpc.main.default_network_acl_id
}

output "vpc_default_security_group_id" {
  description = "ID of the security group created by default on VPC creation"
  value       = aws_vpc.main.default_security_group_id
}

output "vpc_default_route_table_id" {
  description = "ID of the default route table"
  value       = aws_vpc.main.default_route_table_id
}

output "vpc_owner_id" {
  description = "ID of the AWS account that owns the VPC"
  value       = aws_vpc.main.owner_id
}

# =============================================================================
# Internet Gateway Outputs
# =============================================================================

output "igw_id" {
  description = "ID of the Internet Gateway"
  value       = try(aws_internet_gateway.main.id, null)
}

output "igw_arn" {
  description = "ARN of the Internet Gateway"
  value       = try(aws_internet_gateway.main.arn, null)
}

# =============================================================================
# Subnet Outputs
# =============================================================================

# Public Subnets
output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "public_subnet_arns" {
  description = "List of ARNs of public subnets"
  value       = aws_subnet.public[*].arn
}

output "public_subnets_cidr_blocks" {
  description = "List of CIDR blocks of public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "public_subnets_availability_zones" {
  description = "List of availability zones of public subnets"
  value       = aws_subnet.public[*].availability_zone
}

# Private Subnets
output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "private_subnet_arns" {
  description = "List of ARNs of private subnets"
  value       = aws_subnet.private[*].arn
}

output "private_subnets_cidr_blocks" {
  description = "List of CIDR blocks of private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "private_subnets_availability_zones" {
  description = "List of availability zones of private subnets"
  value       = aws_subnet.private[*].availability_zone
}

# Database Subnets
output "database_subnets" {
  description = "List of IDs of database subnets"
  value       = aws_subnet.database[*].id
}

output "database_subnet_arns" {
  description = "List of ARNs of database subnets"
  value       = aws_subnet.database[*].arn
}

output "database_subnets_cidr_blocks" {
  description = "List of CIDR blocks of database subnets"
  value       = aws_subnet.database[*].cidr_block
}

output "database_subnets_availability_zones" {
  description = "List of availability zones of database subnets"
  value       = aws_subnet.database[*].availability_zone
}

# Database Subnet Group
output "database_subnet_group_id" {
  description = "ID of the database subnet group"
  value       = try(aws_db_subnet_group.main.id, null)
}

output "database_subnet_group_arn" {
  description = "ARN of the database subnet group"
  value       = try(aws_db_subnet_group.main.arn, null)
}

# =============================================================================
# Alternative Naming Outputs for Backward Compatibility
# =============================================================================

# Alternative naming for modules that expect "_ids" suffix
output "private_subnet_ids" {
  description = "List of IDs of private subnets (alternative naming)"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets (alternative naming)"
  value       = aws_subnet.public[*].id
}

output "database_subnet_ids" {
  description = "List of IDs of database subnets (alternative naming)"
  value       = aws_subnet.database[*].id
}

# =============================================================================
# NAT Gateway Outputs
# =============================================================================

output "nat_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "nat_public_ips" {
  description = "List of public Elastic IPs of NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "natgw_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

# =============================================================================
# Route Table Outputs
# =============================================================================

# Public Route Tables
output "public_route_table_ids" {
  description = "List of IDs of the public route tables"
  value       = [aws_route_table.public.id]
}

output "public_route_table_association_ids" {
  description = "List of IDs of the public route table associations"
  value       = aws_route_table_association.public[*].id
}

# Private Route Tables
output "private_route_table_ids" {
  description = "List of IDs of the private route tables"
  value       = aws_route_table.private[*].id
}

output "private_route_table_association_ids" {
  description = "List of IDs of the private route table associations"
  value       = aws_route_table_association.private[*].id
}

# Database Route Tables
output "database_route_table_ids" {
  description = "List of IDs of the database route tables"
  value       = [aws_route_table.database.id]
}

output "database_route_table_association_ids" {
  description = "List of IDs of the database route table associations"
  value       = aws_route_table_association.database[*].id
}

# =============================================================================
# Security Group Outputs
# =============================================================================

output "default_security_group_id" {
  description = "ID of the default security group"
  value       = aws_default_security_group.default.id
}

output "web_security_group_id" {
  description = "ID of the web tier security group"
  value       = aws_security_group.web.id
}

output "web_security_group_arn" {
  description = "ARN of the web tier security group"
  value       = aws_security_group.web.arn
}

output "app_security_group_id" {
  description = "ID of the application tier security group"
  value       = aws_security_group.app.id
}

output "app_security_group_arn" {
  description = "ARN of the application tier security group"
  value       = aws_security_group.app.arn
}

output "database_security_group_id" {
  description = "ID of the database tier security group"
  value       = aws_security_group.database.id
}

output "database_security_group_arn" {
  description = "ARN of the database tier security group"
  value       = aws_security_group.database.arn
}

# Security Group IDs by tier (for easy reference)
output "security_groups" {
  description = "Map of security group IDs by tier"
  value = {
    default  = aws_default_security_group.default.id
    web      = aws_security_group.web.id
    app      = aws_security_group.app.id
    database = aws_security_group.database.id
  }
}

# =============================================================================
# Network ACL Outputs
# =============================================================================

output "public_network_acl_id" {
  description = "ID of the public network ACL"
  value       = try(aws_network_acl.public.id, null)
}

output "public_network_acl_arn" {
  description = "ARN of the public network ACL"
  value       = try(aws_network_acl.public.arn, null)
}

output "private_network_acl_id" {
  description = "ID of the private network ACL"
  value       = try(aws_network_acl.private.id, null)
}

output "private_network_acl_arn" {
  description = "ARN of the private network ACL"
  value       = try(aws_network_acl.private.arn, null)
}

output "database_network_acl_id" {
  description = "ID of the database network ACL"
  value       = try(aws_network_acl.database.id, null)
}

output "database_network_acl_arn" {
  description = "ARN of the database network ACL"
  value       = try(aws_network_acl.database.arn, null)
}

# =============================================================================
# VPC Flow Logs Outputs
# =============================================================================

output "vpc_flow_log_id" {
  description = "ID of the VPC Flow Log"
  value       = try(aws_flow_log.vpc[0].id, null)
}

output "vpc_flow_log_cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for VPC Flow Logs"
  value       = try(aws_cloudwatch_log_group.vpc_flow_logs[0].name, null)
}

output "vpc_flow_log_cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for VPC Flow Logs"
  value       = try(aws_cloudwatch_log_group.vpc_flow_logs[0].arn, null)
}

# =============================================================================
# VPC Endpoint Outputs
# =============================================================================

output "vpc_endpoint_s3_id" {
  description = "ID of the S3 VPC Endpoint"
  value       = try(aws_vpc_endpoint.s3[0].id, null)
}

output "vpc_endpoint_s3_prefix_list_id" {
  description = "Prefix list ID of the S3 VPC Endpoint"
  value       = try(aws_vpc_endpoint.s3[0].prefix_list_id, null)
}

output "vpc_endpoint_dynamodb_id" {
  description = "ID of the DynamoDB VPC Endpoint"
  value       = try(aws_vpc_endpoint.dynamodb[0].id, null)
}

output "vpc_endpoint_dynamodb_prefix_list_id" {
  description = "Prefix list ID of the DynamoDB VPC Endpoint"
  value       = try(aws_vpc_endpoint.dynamodb[0].prefix_list_id, null)
}

# =============================================================================
# Availability Zone Outputs
# =============================================================================

output "azs" {
  description = "List of availability zones used"
  value       = local.azs
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = local.azs
}

output "availability_zones_count" {
  description = "Number of availability zones used"
  value       = local.az_count
}

# =============================================================================
# Calculated CIDR Blocks
# =============================================================================

output "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  value       = local.public_subnet_cidrs
}

output "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  value       = local.private_subnet_cidrs
}

output "database_subnet_cidrs" {
  description = "List of CIDR blocks for database subnets"
  value       = local.database_subnet_cidrs
}

# =============================================================================
# Convenient Grouped Outputs
# =============================================================================

output "networking_info" {
  description = "Complete networking information"
  value = {
    vpc_id               = aws_vpc.main.id
    vpc_cidr             = aws_vpc.main.cidr_block
    public_subnets       = aws_subnet.public[*].id
    private_subnets      = aws_subnet.private[*].id
    database_subnets     = aws_subnet.database[*].id
    nat_gateway_ids      = aws_nat_gateway.main[*].id
    internet_gateway_id  = aws_internet_gateway.main.id
    availability_zones   = local.azs
  }
}

output "security_group_info" {
  description = "Security group information"
  value = {
    web_sg      = aws_security_group.web.id
    app_sg      = aws_security_group.app.id
    database_sg = aws_security_group.database.id
    default_sg  = aws_default_security_group.default.id
  }
}

# =============================================================================
# Conditional Outputs (based on enabled features)
# =============================================================================

output "flow_logs_enabled" {
  description = "Whether VPC Flow Logs are enabled"
  value       = var.enable_flow_logs
}

output "nat_gateway_enabled" {
  description = "Whether NAT Gateways are enabled"
  value       = var.enable_nat_gateway
}

output "vpc_endpoints_enabled" {
  description = "Whether VPC Endpoints are enabled"
  value       = var.enable_vpc_endpoints
}
