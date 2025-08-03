#!/bin/bash

# =============================================================================
# AWS Education Platform - Setup Script
# =============================================================================
# This script sets up the development environment for the AWS Education Platform
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required tools
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command_exists node; then
        missing_tools+=("Node.js (v18+)")
    else
        local node_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$node_version" -lt 18 ]; then
            missing_tools+=("Node.js v18+ (current: $(node --version))")
        fi
    fi
    
    if ! command_exists npm; then
        missing_tools+=("npm")
    fi
    
    if ! command_exists terraform; then
        missing_tools+=("Terraform")
    fi
    
    if ! command_exists aws; then
        missing_tools+=("AWS CLI")
    fi
    
    if ! command_exists git; then
        missing_tools+=("Git")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo ""
        echo "Please install the missing tools and run this script again."
        echo "Installation guides:"
        echo "  - Node.js: https://nodejs.org/"
        echo "  - Terraform: https://terraform.io/downloads"
        echo "  - AWS CLI: https://aws.amazon.com/cli/"
        exit 1
    fi
    
    log_success "All prerequisites are installed"
}

# Setup environment file
setup_environment() {
    log_info "Setting up environment configuration..."
    
    if [ ! -f .env ]; then
        if [ -f .env.template ]; then
            cp .env.template .env
            log_success "Created .env file from template"
            log_warning "Please edit .env file with your actual values before proceeding"
        else
            log_error ".env.template file not found"
            exit 1
        fi
    else
        log_info ".env file already exists"
    fi
}

# Install dependencies
install_dependencies() {
    log_info "Installing project dependencies..."
    
    # Install root dependencies
    log_info "Installing root dependencies..."
    npm install
    
    # Install frontend dependencies
    if [ -d "applications/frontend" ]; then
        log_info "Installing frontend dependencies..."
        cd applications/frontend
        npm install
        cd ../..
    fi
    
    # Install backend service dependencies
    if [ -d "applications/backend-services" ]; then
        log_info "Installing backend service dependencies..."
        find applications/backend-services -name package.json -execdir npm install \;
    fi
    
    # Install Lambda function dependencies
    if [ -d "applications/lambda-functions" ]; then
        log_info "Installing Lambda function dependencies..."
        find applications/lambda-functions -name package.json -execdir npm install \;
    fi
    
    # Install test dependencies
    if [ -d "tests" ] && [ -f "tests/package.json" ]; then
        log_info "Installing test dependencies..."
        cd tests
        npm install
        cd ..
    fi
    
    log_success "All dependencies installed"
}

# Setup Git hooks
setup_git_hooks() {
    log_info "Setting up Git hooks..."
    
    if [ -d ".git" ]; then
        # Initialize husky
        npx husky install
        
        # Create pre-commit hook if it doesn't exist
        if [ ! -f ".husky/pre-commit" ]; then
            npx husky add .husky/pre-commit "npx lint-staged"
        fi
        
        log_success "Git hooks configured"
    else
        log_warning "Not a Git repository, skipping Git hooks setup"
    fi
}

# Verify AWS credentials
verify_aws_credentials() {
    log_info "Verifying AWS credentials..."
    
    if aws sts get-caller-identity >/dev/null 2>&1; then
        local account_id=$(aws sts get-caller-identity --query Account --output text)
        local region=$(aws configure get region || echo "not set")
        log_success "AWS credentials are valid"
        log_info "Account ID: $account_id"
        log_info "Default region: $region"
    else
        log_warning "AWS credentials not configured or invalid"
        log_info "Please run 'aws configure' to set up your credentials"
    fi
}

# Initialize Terraform
initialize_terraform() {
    log_info "Initializing Terraform..."
    
    local terraform_dir="terraform/environments/dev"
    
    if [ -d "$terraform_dir" ]; then
        cd "$terraform_dir"
        
        # Check if backend.hcl exists and is configured
        if [ -f "backend.hcl" ]; then
            if grep -q "YOUR_ACTUAL_ACCOUNT_ID" backend.hcl; then
                log_warning "Please update backend.hcl with your actual AWS Account ID"
                log_info "You can find your Account ID by running: aws sts get-caller-identity --query Account --output text"
            else
                log_info "Initializing Terraform with backend configuration..."
                terraform init -backend-config=backend.hcl
                log_success "Terraform initialized"
            fi
        else
            log_warning "backend.hcl not found, initializing without remote backend"
            terraform init
        fi
        
        cd ../../..
    else
        log_error "Terraform directory not found: $terraform_dir"
    fi
}

# Run verification
run_verification() {
    log_info "Running deployment verification..."
    
    if [ -f "scripts/verify-deployment.js" ]; then
        node scripts/verify-deployment.js
    else
        log_warning "Verification script not found, skipping verification"
    fi
}

# Main setup function
main() {
    echo "========================================="
    echo "AWS Education Platform - Setup Script"
    echo "========================================="
    echo ""
    
    check_prerequisites
    setup_environment
    install_dependencies
    setup_git_hooks
    verify_aws_credentials
    initialize_terraform
    run_verification
    
    echo ""
    echo "========================================="
    log_success "Setup completed successfully!"
    echo "========================================="
    echo ""
    echo "Next steps:"
    echo "1. Edit .env file with your actual values"
    echo "2. Update terraform/environments/dev/terraform.tfvars with your configuration"
    echo "3. Run 'npm run terraform:plan' to see what will be created"
    echo "4. Run 'npm run terraform:apply' to deploy the infrastructure"
    echo ""
    echo "For more information, see:"
    echo "- README.md for general information"
    echo "- SETUP_GUIDE.md for detailed setup instructions"
    echo "- docs/DEPLOYMENT.md for deployment guide"
}

# Run main function
main "$@"
