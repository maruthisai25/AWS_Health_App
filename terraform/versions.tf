# =============================================================================
# AWS Education Platform - Terraform Versions and Provider Configuration
# =============================================================================
#
# This file defines the required Terraform version and AWS provider 
# configuration for the AWS Education Platform infrastructure.
#
# Version constraints ensure consistency across different environments
# and team members while allowing for compatible updates.
# =============================================================================

terraform {
  # Minimum Terraform version required
  # Using 1.5.0+ for enhanced features and stability
  required_version = ">= 1.5.0, < 2.0.0"
  
  # Required providers with version constraints
  required_providers {
    # AWS Provider for all AWS resource management
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Allow 5.x versions, block major version changes
    }
    
    # Random provider for generating random values
    # Used for resource naming and secret generation
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
    
    # Local provider for local file operations
    # Used for generating configuration files
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    
    # Null provider for utility resources
    # Used for conditional resource creation and triggers
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    
    # TLS provider for certificate and key generation
    # Used for SSL/TLS certificate management
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# =============================================================================
# AWS Provider Configuration
# =============================================================================

# Primary AWS provider configuration
provider "aws" {
  # AWS region where resources will be created
  region = var.aws_region
  
  # Default tags to apply to all resources
  # These tags will be inherited by all resources created with this provider
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "aws-education-platform"
      CostCenter  = var.cost_center
      Owner       = var.owner
      CreatedDate = formatdate("YYYY-MM-DD", timestamp())
    }
  }
  
  # Assume role configuration (if needed for cross-account access)
  # Uncomment and configure if using cross-account roles
  # assume_role {
  #   role_arn = "arn:aws:iam::${var.aws_account_id}:role/TerraformRole"
  # }
}

# Secondary AWS provider for resources that need to be in us-east-1
# (e.g., CloudFront SSL certificates, Route53 health checks)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  
  # Inherit the same default tags
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "aws-education-platform"
      CostCenter  = var.cost_center
      Owner       = var.owner
      CreatedDate = formatdate("YYYY-MM-DD", timestamp())
    }
  }
}

# =============================================================================
# Data Sources for AWS Account Information
# =============================================================================

# Get current AWS caller identity (account ID, user ARN, etc.)
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

# Get available availability zones in the current region
data "aws_availability_zones" "available" {
  state = "available"
  
  # Exclude zones that might have limited capacity
  exclude_names = ["us-west-1c"]
}

# =============================================================================
# Local Values for Common Computations
# =============================================================================

locals {
  # Account information
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  # Common naming prefix for resources
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Common tags that will be merged with resource-specific tags
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "aws-education-platform"
    CostCenter  = var.cost_center
    Owner       = var.owner
    Region      = local.region
    AccountId   = local.account_id
  }
  
  # Availability zones to use (minimum 2, maximum 3)
  azs = slice(data.aws_availability_zones.available.names, 0, min(3, length(data.aws_availability_zones.available.names)))
  
  # Number of availability zones
  az_count = length(local.azs)
}
