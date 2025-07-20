# =============================================================================
# AWS Education Platform - Terraform Backend Configuration
# =============================================================================
# 
# This file configures the S3 backend for Terraform state management with
# DynamoDB table for state locking to prevent concurrent modifications.
#
# Prerequisites:
# 1. S3 bucket for state storage must be created via bootstrap script
# 2. DynamoDB table for state locking must exist
# 3. Bucket versioning and encryption should be enabled
#
# Usage:
# - Backend configuration cannot use variables or interpolations
# - Use backend.hcl files for environment-specific configurations
# - Run terraform init -backend-config=backend.hcl
# =============================================================================

terraform {
  # Backend configuration is set via backend.hcl files
  # This allows environment-specific backend configurations
  # See terraform/environments/{env}/backend.hcl for actual values
  backend "s3" {
    # Configuration is provided via -backend-config flag
    # terraform init -backend-config=backend.hcl
  }
  
  # Terraform version constraints
  required_version = ">= 1.5.0"
  
  # Required providers with version constraints
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
    
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# =============================================================================
# Bootstrap Script for Backend Setup
# =============================================================================
# 
# If the S3 bucket and DynamoDB table don't exist, run this bootstrap script:
#
# #!/bin/bash
# ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
# REGION=$(aws configure get region || echo "us-east-1")
# BUCKET_NAME="education-platform-terraform-state-${ACCOUNT_ID}-${REGION}"
# 
# # Create S3 bucket for state storage
# aws s3 mb s3://${BUCKET_NAME} --region ${REGION}
# 
# # Enable versioning on the bucket
# aws s3api put-bucket-versioning \
#   --bucket ${BUCKET_NAME} \
#   --versioning-configuration Status=Enabled
# 
# # Enable encryption on the bucket
# aws s3api put-bucket-encryption \
#   --bucket ${BUCKET_NAME} \
#   --server-side-encryption-configuration '{
#     "Rules": [{
#       "ApplyServerSideEncryptionByDefault": {
#         "SSEAlgorithm": "AES256"
#       }
#     }]
#   }'
# 
# # Block public access to the bucket
# aws s3api put-public-access-block \
#   --bucket ${BUCKET_NAME} \
#   --public-access-block-configuration \
#     BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
# 
# # Create DynamoDB table for state locking
# aws dynamodb create-table \
#   --table-name education-platform-terraform-locks \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
#   --region ${REGION}
# 
# echo "Backend resources created successfully!"
# =============================================================================
