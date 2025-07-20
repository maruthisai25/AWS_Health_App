#!/bin/bash

# =============================================================================
# AWS Education Platform - Deployment Helper Script
# =============================================================================
#
# This script provides a convenient way to deploy the AWS Education Platform
# to different environments using Terraform and GitHub Actions.
#
# Usage:
#   ./scripts/deploy.sh [environment] [component] [options]
#
# Examples:
#   ./scripts/deploy.sh dev                    # Deploy all components to dev
#   ./scripts/deploy.sh prod infrastructure    # Deploy only infrastructure to prod
#   ./scripts/deploy.sh staging frontend      # Deploy only frontend to staging
#   ./scripts/deploy.sh dev --destroy          # Destroy dev environment
#   ./scripts/deploy.sh --help                 # Show help
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=""
COMPONENT="all"
DESTROY=false
DRY_RUN=false
VERBOSE=false
SKIP_TESTS=false

# Available environments
VALID_ENVIRONMENTS=("dev" "staging" "prod")

# Available components
VALID_COMPONENTS=("all" "infrastructure" "frontend" "lambda" "backend")

# =============================================================================
# Helper Functions
# =============================================================================

print_usage() {
    cat << EOF
AWS Education Platform Deployment Script

USAGE:
    $0 [ENVIRONMENT] [COMPONENT] [OPTIONS]

ENVIRONMENTS:
    dev         Development environment
    staging     Staging environment  
    prod        Production environment

COMPONENTS:
    all            Deploy all components (default)
    infrastructure Deploy Terraform infrastructure only
    frontend       Deploy React frontend only
    lambda         Deploy Lambda functions only
    backend        Deploy backend services only

OPTIONS:
    --destroy      Destroy the specified environment
    --dry-run      Show what would be deployed without executing
    --verbose      Enable verbose output
    --skip-tests   Skip running tests before deployment
    --help         Show this help message

EXAMPLES:
    $0 dev                           # Deploy everything to dev
    $0 prod infrastructure           # Deploy only infrastructure to prod
    $0 staging frontend              # Deploy only frontend to staging
    $0 dev --destroy                 # Destroy dev environment
    $0 prod --dry-run                # Show what would be deployed to prod

PREREQUISITES:
    - AWS CLI configured with appropriate credentials
    - Terraform installed (version 1.5+)
    - Node.js installed (version 18+)
    - GitHub CLI (gh) for triggering workflows
    - Required environment variables set

ENVIRONMENT VARIABLES:
    AWS_ACCOUNT_ID     Your AWS Account ID
    AWS_REGION         AWS region (default: us-east-1)
    DB_PASSWORD        Database password for RDS
    GITHUB_TOKEN       GitHub personal access token

EOF
}

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Check if element is in array
contains_element() {
    local element="$1"
    shift
    local array=("$@")
    for item in "${array[@]}"; do
        [[ "$item" == "$element" ]] && return 0
    done
    return 1
}

# Validate environment
validate_environment() {
    if [[ -z "$ENVIRONMENT" ]]; then
        error "Environment is required. Use: dev, staging, or prod"
    fi
    
    if ! contains_element "$ENVIRONMENT" "${VALID_ENVIRONMENTS[@]}"; then
        error "Invalid environment: $ENVIRONMENT. Valid options: ${VALID_ENVIRONMENTS[*]}"
    fi
}

# Validate component
validate_component() {
    if ! contains_element "$COMPONENT" "${VALID_COMPONENTS[@]}"; then
        error "Invalid component: $COMPONENT. Valid options: ${VALID_COMPONENTS[*]}"
    fi
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check required tools
    command -v aws >/dev/null 2>&1 || error "AWS CLI is required but not installed"
    command -v terraform >/dev/null 2>&1 || error "Terraform is required but not installed"
    command -v node >/dev/null 2>&1 || error "Node.js is required but not installed"
    command -v gh >/dev/null 2>&1 || error "GitHub CLI is required but not installed"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        error "AWS credentials not configured or invalid"
    fi
    
    # Check required environment variables
    [[ -z "$AWS_ACCOUNT_ID" ]] && error "AWS_ACCOUNT_ID environment variable is required"
    [[ -z "$DB_PASSWORD" ]] && error "DB_PASSWORD environment variable is required"
    
    # Set defaults
    export AWS_REGION="${AWS_REGION:-us-east-1}"
    
    success "Prerequisites check passed"
}

# Deploy infrastructure using Terraform
deploy_infrastructure() {
    log "Deploying infrastructure to $ENVIRONMENT..."
    
    cd "terraform/environments/$ENVIRONMENT"
    
    # Initialize Terraform
    if [[ ! -f ".terraform/terraform.tfstate" ]]; then
        log "Initializing Terraform..."
        terraform init -backend-config=backend.hcl
    fi
    
    # Plan deployment
    log "Planning Terraform deployment..."
    if [[ "$DRY_RUN" == "true" ]]; then
        terraform plan -no-color
        return 0
    fi
    
    # Apply deployment
    if [[ "$DESTROY" == "true" ]]; then
        warning "This will destroy all infrastructure in $ENVIRONMENT environment!"
        read -p "Are you sure? (yes/no): " -r
        if [[ $REPLY == "yes" ]]; then
            terraform destroy -auto-approve
            success "Infrastructure destroyed in $ENVIRONMENT"
        else
            log "Deployment cancelled"
        fi
    else
        terraform apply -auto-approve
        success "Infrastructure deployed to $ENVIRONMENT"
    fi
    
    cd - >/dev/null
}

# Deploy frontend using GitHub Actions
deploy_frontend() {
    log "Deploying frontend to $ENVIRONMENT..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Would trigger frontend deployment workflow for $ENVIRONMENT"
        return 0
    fi
    
    # Trigger GitHub Actions workflow
    gh workflow run frontend-deploy.yml \
        -f environment="$ENVIRONMENT" \
        --repo "$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^/]*\/[^/]*\).*/\1/' | sed 's/\.git$//')"
    
    success "Frontend deployment triggered for $ENVIRONMENT"
}

# Deploy Lambda functions using GitHub Actions
deploy_lambda() {
    log "Deploying Lambda functions to $ENVIRONMENT..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Would trigger Lambda deployment workflow for $ENVIRONMENT"
        return 0
    fi
    
    # Trigger GitHub Actions workflow
    gh workflow run lambda-deploy.yml \
        -f environment="$ENVIRONMENT" \
        --repo "$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^/]*\/[^/]*\).*/\1/' | sed 's/\.git$//')"
    
    success "Lambda deployment triggered for $ENVIRONMENT"
}

# Deploy backend services using GitHub Actions
deploy_backend() {
    log "Deploying backend services to $ENVIRONMENT..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Would trigger backend deployment workflow for $ENVIRONMENT"
        return 0
    fi
    
    # Trigger GitHub Actions workflow
    gh workflow run backend-deploy.yml \
        -f environment="$ENVIRONMENT" \
        --repo "$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^/]*\/[^/]*\).*/\1/' | sed 's/\.git$//')"
    
    success "Backend deployment triggered for $ENVIRONMENT"
}

# Run tests
run_tests() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        warning "Skipping tests as requested"
        return 0
    fi
    
    log "Running tests..."
    
    # Frontend tests
    if [[ -f "applications/frontend/package.json" ]]; then
        log "Running frontend tests..."
        cd applications/frontend
        npm ci
        npm test -- --watchAll=false
        cd - >/dev/null
    fi
    
    # Lambda function tests
    for func_dir in applications/lambda-functions/*/; do
        if [[ -f "$func_dir/package.json" ]]; then
            func_name=$(basename "$func_dir")
            log "Running tests for $func_name..."
            cd "$func_dir"
            npm ci
            if npm run | grep -q "test"; then
                npm test
            fi
            cd - >/dev/null
        fi
    done
    
    # Backend service tests
    for service_dir in applications/backend-services/*/; do
        if [[ -f "$service_dir/package.json" ]]; then
            service_name=$(basename "$service_dir")
            log "Running tests for $service_name..."
            cd "$service_dir"
            npm ci
            if npm run | grep -q "test"; then
                npm test
            fi
            cd - >/dev/null
        fi
    done
    
    success "All tests passed"
}

# Get deployment status
get_status() {
    log "Getting deployment status for $ENVIRONMENT..."
    
    cd "terraform/environments/$ENVIRONMENT"
    
    if [[ -f "terraform.tfstate" ]]; then
        log "Infrastructure status:"
        terraform show -no-color | head -20
        
        log "Getting outputs..."
        terraform output -json > "/tmp/terraform-outputs-$ENVIRONMENT.json"
        
        # Display key outputs
        if command -v jq >/dev/null 2>&1; then
            echo ""
            log "Key endpoints:"
            jq -r '.website_url.value // "N/A"' "/tmp/terraform-outputs-$ENVIRONMENT.json" | sed 's/^/  Website: /'
            jq -r '.api_gateway_url.value // "N/A"' "/tmp/terraform-outputs-$ENVIRONMENT.json" | sed 's/^/  API Gateway: /'
            jq -r '.monitoring_dashboard_url.value // "N/A"' "/tmp/terraform-outputs-$ENVIRONMENT.json" | sed 's/^/  Monitoring: /'
        fi
    else
        warning "No Terraform state found for $ENVIRONMENT"
    fi
    
    cd - >/dev/null
}

# =============================================================================
# Main Script Logic
# =============================================================================

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            print_usage
            exit 0
            ;;
        --destroy)
            DESTROY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            set -x
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        dev|staging|prod)
            ENVIRONMENT="$1"
            shift
            ;;
        all|infrastructure|frontend|lambda|backend)
            COMPONENT="$1"
            shift
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Validate inputs
validate_environment
validate_component

# Check prerequisites
check_prerequisites

# Show deployment plan
log "Deployment Plan:"
echo "  Environment: $ENVIRONMENT"
echo "  Component: $COMPONENT"
echo "  Destroy: $DESTROY"
echo "  Dry Run: $DRY_RUN"
echo "  Skip Tests: $SKIP_TESTS"
echo ""

# Confirm production deployments
if [[ "$ENVIRONMENT" == "prod" && "$DESTROY" == "false" && "$DRY_RUN" == "false" ]]; then
    warning "You are about to deploy to PRODUCTION!"
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ $REPLY != "yes" ]]; then
        log "Deployment cancelled"
        exit 0
    fi
fi

# Run tests (unless skipped or destroying)
if [[ "$DESTROY" == "false" ]]; then
    run_tests
fi

# Execute deployment based on component
case $COMPONENT in
    all)
        deploy_infrastructure
        if [[ "$DESTROY" == "false" ]]; then
            deploy_frontend
            deploy_lambda
            deploy_backend
        fi
        ;;
    infrastructure)
        deploy_infrastructure
        ;;
    frontend)
        deploy_frontend
        ;;
    lambda)
        deploy_lambda
        ;;
    backend)
        deploy_backend
        ;;
esac

# Show status (unless destroying)
if [[ "$DESTROY" == "false" && "$DRY_RUN" == "false" ]]; then
    sleep 5  # Wait a moment for resources to be ready
    get_status
fi

success "Deployment script completed successfully!"

# Show next steps
if [[ "$DESTROY" == "false" && "$DRY_RUN" == "false" ]]; then
    echo ""
    log "Next steps:"
    echo "  1. Monitor GitHub Actions workflows for deployment progress"
    echo "  2. Check application health at the provided URLs"
    echo "  3. Review CloudWatch logs and metrics"
    echo "  4. Run integration tests if needed"
fi