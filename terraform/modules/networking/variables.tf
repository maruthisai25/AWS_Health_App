
# =============================================================================
# Networking Module Variables
# =============================================================================

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
  validation {
    condition     = var.availability_zones_count >= 2 && var.availability_zones_count <= 6
    error_message = "Availability zones count must be between 2 and 6."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_dns_hostnames" {
  description = "Whether to enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Whether to enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "enable_ipv6" {
  description = "Whether to enable IPv6 for the VPC"
  type        = bool
  default     = false
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "single_nat_gateway" {
  description = "Whether to use a single NAT gateway instead of one per AZ"
  type        = bool
  default     = false
}

# =============================================================================
# VPN Gateway Configuration
# =============================================================================

variable "enable_vpn_gateway" {
  description = "Whether to create a VPN gateway for the VPC"
  type        = bool
  default     = false
}

variable "vpn_gateway_amazon_side_asn" {
  description = "The Autonomous System Number (ASN) for the Amazon side of the gateway"
  type        = number
  default     = 64512
}

# =============================================================================
# VPC Flow Logs Configuration
# =============================================================================

variable "enable_flow_logs" {
  description = "Whether to enable VPC flow logs"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain VPC flow logs in CloudWatch"
  type        = number
  default     = 30
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.flow_logs_retention_days)
    error_message = "Flow logs retention days must be a valid CloudWatch log retention value."
  }
}

variable "flow_logs_traffic_type" {
  description = "Type of traffic to capture in flow logs"
  type        = string
  default     = "ALL"
  
  validation {
    condition     = contains(["ALL", "ACCEPT", "REJECT"], var.flow_logs_traffic_type)
    error_message = "Flow logs traffic type must be one of: ALL, ACCEPT, REJECT."
  }
}

# =============================================================================
# VPC Endpoints Configuration
# =============================================================================

variable "enable_vpc_endpoints" {
  description = "Whether to create VPC endpoints for AWS services"
  type        = bool
  default     = false
}

variable "vpc_endpoints" {
  description = "Map of VPC endpoints to create"
  type = map(object({
    service_name      = string
    vpc_endpoint_type = string
    route_table_ids   = list(string)
    policy            = string
  }))
  default = {}
}

# =============================================================================
# Security Group Configuration
# =============================================================================

variable "enable_default_security_group_with_custom_rules" {
  description = "Whether to enable default security group with custom rules"
  type        = bool
  default     = false
}

variable "default_security_group_ingress" {
  description = "List of ingress rules for default security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "default_security_group_egress" {
  description = "List of egress rules for default security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "additional_security_group_rules" {
  description = "Additional security group rules to add"
  type = map(list(object({
    type        = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  })))
  default = {}
}

# =============================================================================
# Network ACL Configuration
# =============================================================================

variable "enable_custom_nacls" {
  description = "Whether to create custom Network ACLs"
  type        = bool
  default     = true
}

variable "public_nacl_ingress_rules" {
  description = "List of ingress rules for public network ACL"
  type = list(object({
    rule_no    = number
    protocol   = string
    action     = string
    cidr_block = string
    from_port  = number
    to_port    = number
  }))
  default = []
}

variable "public_nacl_egress_rules" {
  description = "List of egress rules for public network ACL"
  type = list(object({
    rule_no    = number
    protocol   = string
    action     = string
    cidr_block = string
    from_port  = number
    to_port    = number
  }))
  default = []
}

variable "private_nacl_ingress_rules" {
  description = "List of ingress rules for private network ACL"
  type = list(object({
    rule_no    = number
    protocol   = string
    action     = string
    cidr_block = string
    from_port  = number
    to_port    = number
  }))
  default = []
}

variable "private_nacl_egress_rules" {
  description = "List of egress rules for private network ACL"
  type = list(object({
    rule_no    = number
    protocol   = string
    action     = string
    cidr_block = string
    from_port  = number
    to_port    = number
  }))
  default = []
}

# =============================================================================
# Subnet Configuration
# =============================================================================

variable "public_subnet_suffix" {
  description = "Suffix to append to public subnet names"
  type        = string
  default     = "public"
}

variable "private_subnet_suffix" {
  description = "Suffix to append to private subnet names"
  type        = string
  default     = "private"
}

variable "database_subnet_suffix" {
  description = "Suffix to append to database subnet names"
  type        = string
  default     = "database"
}

variable "map_public_ip_on_launch" {
  description = "Whether to assign public IPs to instances launched in public subnets"
  type        = bool
  default     = true
}

# =============================================================================
# Database Subnet Group Configuration
# =============================================================================

variable "create_database_subnet_group" {
  description = "Whether to create a database subnet group"
  type        = bool
  default     = true
}

variable "database_subnet_group_name" {
  description = "Name of the database subnet group (if not provided, will be auto-generated)"
  type        = string
  default     = ""
}

# =============================================================================
# Route Table Configuration
# =============================================================================

variable "propagate_private_route_tables_vgw" {
  description = "Whether to propagate private route tables with VGW"
  type        = bool
  default     = false
}

variable "propagate_public_route_tables_vgw" {
  description = "Whether to propagate public route tables with VGW"
  type        = bool
  default     = false
}

# =============================================================================
# Internet Gateway Configuration
# =============================================================================

variable "create_igw" {
  description = "Whether to create an Internet Gateway"
  type        = bool
  default     = true
}

variable "igw_tags" {
  description = "Additional tags for the Internet Gateway"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Cost Optimization Configuration
# =============================================================================

variable "enable_cost_optimization" {
  description = "Whether to enable cost optimization features"
  type        = bool
  default     = false
}

variable "cost_optimization_features" {
  description = "List of cost optimization features to enable"
  type = object({
    single_nat_gateway     = bool
    nat_instance_instead   = bool
    smaller_subnet_sizes   = bool
    reduce_az_count        = bool
  })
  default = {
    single_nat_gateway     = false
    nat_instance_instead   = false
    smaller_subnet_sizes   = false
    reduce_az_count        = false
  }
}

# =============================================================================
# Monitoring and Logging Configuration
# =============================================================================

variable "enable_cloudwatch_logs" {
  description = "Whether to enable CloudWatch logs"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 30
}

variable "enable_enhanced_monitoring" {
  description = "Whether to enable enhanced monitoring features"
  type        = bool
  default     = false
}

# =============================================================================
# Advanced Configuration
# =============================================================================

variable "enable_classiclink" {
  description = "Whether to enable ClassicLink for the VPC"
  type        = bool
  default     = false
}

variable "enable_classiclink_dns_support" {
  description = "Whether to enable ClassicLink DNS support for the VPC"
  type        = bool
  default     = false
}

variable "instance_tenancy" {
  description = "Instance tenancy option for the VPC"
  type        = string
  default     = "default"
  
  validation {
    condition     = contains(["default", "dedicated"], var.instance_tenancy)
    error_message = "Instance tenancy must be either 'default' or 'dedicated'."
  }
}

variable "enable_network_address_usage_metrics" {
  description = "Whether to enable network address usage metrics"
  type        = bool
  default     = false
}

# =============================================================================
# Missing Variables Used in main.tf
# =============================================================================

variable "subnet_tags" {
  description = "Additional tags to apply to subnets"
  type        = map(string)
  default     = {}
}

variable "enable_nat_gateway" {
  description = "Whether to enable NAT gateway for private subnet internet access"
  type        = bool
  default     = true
}
