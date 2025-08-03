#!/bin/bash

# AWS Education Platform - Environment Setup
# Cross-platform script to set up the development environment

set -e

echo "🔧 AWS Education Platform - Environment Setup"
echo "=============================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check AWS CLI
echo "🔍 Checking AWS CLI installation..."
if ! command_exists aws; then
    echo "❌ AWS CLI is not installed"
    echo "Please install AWS CLI from: https://aws.amazon.com/cli/"
    echo "Then configure it with: aws configure"
    exit 1
fi

echo "✅ AWS CLI is installed"

# Get AWS Account ID
echo "🔍 Getting AWS Account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "❌ Could not get AWS Account ID"
    echo "Please run: aws configure"
    echo "And ensure you have valid AWS credentials"
    exit 1
fi

echo "✅ AWS Account ID: $AWS_ACCOUNT_ID"

# Create .env file from template
echo "📝 Setting up environment file..."
if [ ! -f ".env" ]; then
    if [ -f ".env.template" ]; then
        cp .env.template .env
        echo "✅ Created .env file from template"
        echo "⚠️  Please edit .env file and add your specific configuration"
    else
        echo "❌ .env.template not found"
    fi
else
    echo "✅ .env file already exists"
fi

# Update Terraform configuration files
echo "📝 Updating Terraform configuration..."

# Update terraform.tfvars if it exists
if [ -f "terraform/environments/dev/terraform.tfvars.example" ]; then
    if [ ! -f "terraform/environments/dev/terraform.tfvars" ]; then
        cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars
        # Replace placeholder with actual account ID
        sed -i.bak "s/YOUR_ACTUAL_ACCOUNT_ID/$AWS_ACCOUNT_ID/g" terraform/environments/dev/terraform.tfvars
        rm terraform/environments/dev/terraform.tfvars.bak 2>/dev/null || true
        echo "✅ Created terraform.tfvars with your AWS Account ID"
    else
        echo "✅ terraform.tfvars already exists"
    fi
fi

# Update backend.hcl if it exists
if [ -f "terraform/environments/dev/backend.hcl" ]; then
    sed -i.bak "s/YOUR_ACTUAL_ACCOUNT_ID/$AWS_ACCOUNT_ID/g" terraform/environments/dev/backend.hcl
    rm terraform/environments/dev/backend.hcl.bak 2>/dev/null || true
    echo "✅ Updated backend.hcl with your AWS Account ID"
fi

# Install dependencies
echo "📦 Installing dependencies..."
./scripts/install-dependencies.sh

echo ""
echo "✅ Environment setup complete!"
echo ""
echo "=============================================="
echo "Next steps:"
echo "=============================================="
echo "1. Edit .env file with your specific configuration"
echo "2. Set database password: export TF_VAR_db_password='YourSecurePassword123!'"
echo "3. Navigate to terraform: cd terraform/environments/dev"
echo "4. Initialize Terraform: terraform init"
echo "5. Plan deployment: terraform plan"
echo "6. Deploy infrastructure: terraform apply"
echo "=============================================="
