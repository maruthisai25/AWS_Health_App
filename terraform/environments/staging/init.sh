#!/bin/bash
# Terraform initialization script for dev environment

echo "Initializing Terraform for dev environment..."

# Check if backend.hcl exists
if [ ! -f "backend.hcl" ]; then
    echo "ERROR: backend.hcl file not found!"
    echo "Please ensure you have updated backend.hcl with your AWS Account ID"
    exit 1
fi

# Initialize Terraform with backend configuration
terraform init -backend-config=backend.hcl

# Validate configuration
terraform validate

echo "Terraform initialized successfully for dev environment"
echo ""
echo "Next steps:"
echo "1. Set your database password: export TF_VAR_db_password='YourSecurePassword'"
echo "2. Update terraform.tfvars with your AWS Account ID"
echo "3. Run: terraform plan"
echo "4. Run: terraform apply"
