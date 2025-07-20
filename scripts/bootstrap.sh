#!/bin/bash

# =============================================================================
# AWS Education Platform - Bootstrap Script
# =============================================================================
#
# This script creates the necessary resources for Terraform backend:
# - S3 bucket for state storage
# - DynamoDB table for state locking
# - Proper bucket policies and encryption
#
# Run this script BEFORE running terraform init for the first time.
# =============================================================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Configuration
# =============================================================================

PROJECT_NAME="education-platform"
ENVIRONMENT=${1:-"dev"}  # Default to dev if not specified

print_status "Starting bootstrap for AWS Education Platform - Environment: $ENVIRONMENT"

# =============================================================================
# Check Prerequisites
# =============================================================================

print_status "Checking prerequisites..."

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_warning "jq is not installed. Some features may not work properly."
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

print_success "Prerequisites check passed"

# =============================================================================
# Get AWS Account Information
# =============================================================================

print_status "Getting AWS account information..."

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")
USER_ARN=$(aws sts get-caller-identity --query Arn --output text)

print_status "Account ID: $ACCOUNT_ID"
print_status "Region: $REGION" 
print_status "User: $USER_ARN"

# =============================================================================
# Define Resource Names
# =============================================================================

BUCKET_NAME="${PROJECT_NAME}-terraform-state-${ACCOUNT_ID}-${REGION}"
DYNAMODB_TABLE="${PROJECT_NAME}-terraform-locks"

print_status "S3 Bucket: $BUCKET_NAME"
print_status "DynamoDB Table: $DYNAMODB_TABLE"

# =============================================================================
# Create S3 Bucket for Terraform State
# =============================================================================

print_status "Creating S3 bucket for Terraform state..."

# Check if bucket already exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    print_warning "S3 bucket $BUCKET_NAME already exists"
else
    # Create bucket
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
    else
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" \
            --create-bucket-configuration LocationConstraint="$REGION"
    fi
    print_success "S3 bucket $BUCKET_NAME created"
fi

# Enable versioning
print_status "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled
print_success "Versioning enabled"

# Enable encryption
print_status "Enabling encryption on S3 bucket..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'
print_success "Encryption enabled"

# Block public access
print_status "Blocking public access to S3 bucket..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
print_success "Public access blocked"

# =============================================================================
# Create DynamoDB Table for State Locking
# =============================================================================

print_status "Creating DynamoDB table for state locking..."

# Check if table already exists
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" &>/dev/null; then
    print_warning "DynamoDB table $DYNAMODB_TABLE already exists"
else
    # Create table
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$REGION" \
        --tags Key=Project,Value="$PROJECT_NAME" \
               Key=Environment,Value="$ENVIRONMENT" \
               Key=Purpose,Value="terraform-locking" \
               Key=ManagedBy,Value="bootstrap-script"
    
    print_status "Waiting for DynamoDB table to be created..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$REGION"
    print_success "DynamoDB table $DYNAMODB_TABLE created"
fi

# =============================================================================
# Create Backend Configuration File
# =============================================================================

print_status "Creating backend configuration file..."

BACKEND_CONFIG_FILE="terraform/environments/$ENVIRONMENT/backend.hcl"
mkdir -p "terraform/environments/$ENVIRONMENT"

cat > "$BACKEND_CONFIG_FILE" << EOF
# Terraform Backend Configuration for $ENVIRONMENT environment
# Generated by bootstrap script on $(date)

bucket         = "$BUCKET_NAME"
key            = "environments/$ENVIRONMENT/terraform.tfstate"
region         = "$REGION"
dynamodb_table = "$DYNAMODB_TABLE"
encrypt        = true
EOF

print_success "Backend configuration created: $BACKEND_CONFIG_FILE"

# =============================================================================
# Create Environment-Specific Configuration
# =============================================================================

print_status "Creating environment-specific configuration..."

# Create .env file for the environment
ENV_FILE="terraform/environments/$ENVIRONMENT/.env"
cat > "$ENV_FILE" << EOF
# Environment variables for $ENVIRONMENT
# Generated by bootstrap script on $(date)

AWS_ACCOUNT_ID=$ACCOUNT_ID
AWS_REGION=$REGION
ENVIRONMENT=$ENVIRONMENT
PROJECT_NAME=$PROJECT_NAME

# Terraform Backend
TF_BACKEND_BUCKET=$BUCKET_NAME
TF_BACKEND_KEY=environments/$ENVIRONMENT/terraform.tfstate
TF_BACKEND_DYNAMODB_TABLE=$DYNAMODB_TABLE

# Database (SET PASSWORD MANUALLY)
TF_VAR_db_password=REPLACE_WITH_SECURE_PASSWORD

# To use these variables, run:
# source $ENV_FILE
EOF

print_success "Environment file created: $ENV_FILE"

# =============================================================================
# Create Initialization Script
# =============================================================================

INIT_SCRIPT="terraform/environments/$ENVIRONMENT/init.sh"
cat > "$INIT_SCRIPT" << EOF
#!/bin/bash
# Terraform initialization script for $ENVIRONMENT environment
# Generated by bootstrap script on $(date)

echo "Initializing Terraform for $ENVIRONMENT environment..."

# Load environment variables
if [ -f ".env" ]; then
    source .env
    echo "Environment variables loaded"
fi

# Initialize Terraform with backend configuration
terraform init -backend-config=backend.hcl

# Validate configuration
terraform validate

echo "Terraform initialized successfully for $ENVIRONMENT environment"
echo ""
echo "Next steps:"
echo "1. Set your database password: export TF_VAR_db_password='YourSecurePassword'"
echo "2. Update terraform.tfvars with your AWS Account ID"
echo "3. Run: terraform plan"
echo "4. Run: terraform apply"
EOF

chmod +x "$INIT_SCRIPT"
print_success "Initialization script created: $INIT_SCRIPT"

# =============================================================================
# Final Instructions
# =============================================================================

print_success "Bootstrap completed successfully!"
echo ""
echo -e "${GREEN}===================================================${NC}"
echo -e "${GREEN}           BOOTSTRAP SUMMARY${NC}"
echo -e "${GREEN}===================================================${NC}"
echo ""
echo -e "${BLUE}Resources Created:${NC}"
echo "  ✓ S3 Bucket: $BUCKET_NAME"
echo "  ✓ DynamoDB Table: $DYNAMODB_TABLE"
echo "  ✓ Backend Config: $BACKEND_CONFIG_FILE"
echo "  ✓ Environment File: $ENV_FILE"
echo "  ✓ Init Script: $INIT_SCRIPT"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Navigate to: cd terraform/environments/$ENVIRONMENT"
echo "  2. Set database password: export TF_VAR_db_password='YourSecurePassword'"
echo "  3. Update terraform.tfvars with your AWS Account ID"
echo "  4. Run initialization script: ./init.sh"
echo "  5. Plan deployment: terraform plan"
echo "  6. Apply configuration: terraform apply"
echo ""
echo -e "${YELLOW}Important Security Notes:${NC}"
echo "  - Never commit passwords to version control"
echo "  - Use strong passwords for database access"
echo "  - Restrict CIDR blocks in production environments"
echo "  - Enable MFA on your AWS account"
echo ""
echo -e "${GREEN}Bootstrap completed for $ENVIRONMENT environment!${NC}"
