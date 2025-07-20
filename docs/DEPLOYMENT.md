# AWS Education Platform - Deployment Guide

## Overview

This comprehensive deployment guide will walk you through setting up the AWS Education Platform from initial AWS account setup to a fully functional production environment. The platform uses Infrastructure as Code (Terraform) and automated CI/CD pipelines for reliable, repeatable deployments.

## Prerequisites

### Required Tools
- **AWS CLI** (version 2.0+)
- **Terraform** (version 1.5+)
- **Node.js** (version 18+)
- **Git** (version 2.0+)
- **GitHub CLI** (optional, for workflow management)

### AWS Account Requirements
- AWS Account with administrative access
- AWS CLI configured with appropriate credentials
- Sufficient service limits for the platform components
- Domain name (optional, for custom domains)

### Installation Commands

#### macOS (using Homebrew)
```bash
# Install required tools
brew install awscli terraform node git gh

# Verify installations
aws --version
terraform --version
node --version
git --version
```

#### Ubuntu/Debian
```bash
# Update package list
sudo apt update

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Git
sudo apt install git

# Verify installations
aws --version
terraform --version
node --version
git --version
```

#### Windows (using Chocolatey)
```powershell
# Install Chocolatey (if not already installed)
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install required tools
choco install awscli terraform nodejs git gh

# Verify installations
aws --version
terraform --version
node --version
git --version
```

## Initial Setup

### 1. Clone the Repository
```bash
git clone https://github.com/your-org/aws-education-platform.git
cd aws-education-platform
```

### 2. Configure AWS Credentials
```bash
# Configure AWS CLI
aws configure

# Verify configuration
aws sts get-caller-identity
```

### 3. Set Environment Variables
Create a `.env` file in the project root:
```bash
# AWS Configuration
export AWS_ACCOUNT_ID="123456789012"  # Replace with your AWS Account ID
export AWS_REGION="us-east-1"         # Your preferred AWS region
export AWS_PROFILE="default"          # AWS CLI profile to use

# Database Configuration
export DB_PASSWORD="YourSecurePassword123!"  # Strong database password

# GitHub Configuration (for CI/CD)
export GITHUB_TOKEN="ghp_your_github_token"  # GitHub Personal Access Token

# Domain Configuration (optional)
export DOMAIN_NAME="yourdomain.com"          # Your custom domain
export SUBDOMAIN="app"                       # Subdomain for the application

# Load environment variables
source .env
```

### 4. Verify Prerequisites
```bash
# Run the prerequisite check script
./scripts/check-prerequisites.sh

# Or manually verify
echo "AWS Account ID: $(aws sts get-caller-identity --query Account --output text)"
echo "AWS Region: $AWS_REGION"
echo "Terraform Version: $(terraform --version | head -n1)"
echo "Node.js Version: $(node --version)"
```

## Environment Setup

### Development Environment

#### 1. Bootstrap Backend Resources
```bash
# Make the bootstrap script executable
chmod +x scripts/bootstrap.sh

# Bootstrap development environment
./scripts/bootstrap.sh dev

# This creates:
# - S3 bucket for Terraform state
# - DynamoDB table for state locking
# - Initial IAM roles and policies
```

#### 2. Initialize Terraform
```bash
cd terraform/environments/dev

# Initialize Terraform with backend configuration
terraform init -backend-config=backend.hcl

# Validate configuration
terraform validate

# Plan deployment
terraform plan

# Apply infrastructure (this will take 15-20 minutes)
terraform apply
```

#### 3. Deploy Applications
```bash
# Return to project root
cd ../../..

# Install frontend dependencies
cd applications/frontend
npm install

# Build and deploy frontend
npm run build
npm run deploy

# Install Lambda function dependencies
cd ../lambda-functions
for dir in */; do
  cd "$dir"
  if [ -f "package.json" ]; then
    npm install
  fi
  cd ..
done

# Deploy Lambda functions (if using manual deployment)
# Note: GitHub Actions will handle this automatically
```

#### 4. Verify Deployment
```bash
# Get deployment outputs
cd terraform/environments/dev
terraform output

# Test endpoints
curl -f $(terraform output -raw website_url)
curl -f $(terraform output -raw api_gateway_url)/health
```

### Staging Environment

#### 1. Create Staging Configuration
```bash
# Copy dev configuration as starting point
cp -r terraform/environments/dev terraform/environments/staging

# Update staging-specific values in terraform.tfvars
cd terraform/environments/staging
```

Edit `terraform.tfvars`:
```hcl
# Staging-specific configuration
environment = "staging"
enable_multi_az = true
instance_types = {
  web_tier = "t3.small"
  app_tier = "t3.medium"
  db_tier  = "db.t3.small"
}
backup_retention_period = 7
log_retention_days = 14
```

#### 2. Deploy Staging Environment
```bash
# Initialize Terraform
terraform init -backend-config=backend.hcl

# Plan and apply
terraform plan
terraform apply
```

### Production Environment

#### 1. Create Production Configuration
```bash
# Copy staging configuration
cp -r terraform/environments/staging terraform/environments/prod

# Update production-specific values
cd terraform/environments/prod
```

Edit `terraform.tfvars`:
```hcl
# Production configuration
environment = "prod"
enable_multi_az = true
enable_deletion_protection = true
instance_types = {
  web_tier = "t3.medium"
  app_tier = "t3.large"
  db_tier  = "db.r6g.large"
}
backup_retention_period = 30
log_retention_days = 30
enable_performance_insights = true
enable_enhanced_monitoring = true
```

#### 2. Deploy Production Environment
```bash
# Initialize Terraform
terraform init -backend-config=backend.hcl

# Plan deployment (review carefully)
terraform plan

# Apply with approval
terraform apply
```

## CI/CD Pipeline Setup

### 1. GitHub Repository Setup
```bash
# Create GitHub repository (if not already done)
gh repo create aws-education-platform --public

# Push code to repository
git add .
git commit -m "Initial commit"
git push origin main
```

### 2. Configure GitHub Secrets
```bash
# Set required secrets
gh secret set AWS_ACCESS_KEY_ID --body "$AWS_ACCESS_KEY_ID"
gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY"
gh secret set AWS_ACCOUNT_ID --body "$AWS_ACCOUNT_ID"
gh secret set DB_PASSWORD --body "$DB_PASSWORD"
gh secret set GITHUB_TOKEN --body "$GITHUB_TOKEN"

# Optional secrets for enhanced features
gh secret set SNYK_TOKEN --body "$SNYK_TOKEN"
gh secret set INFRACOST_API_KEY --body "$INFRACOST_API_KEY"
```

### 3. Configure GitHub Environments
```bash
# Create environments with protection rules
gh api repos/:owner/:repo/environments/production -X PUT --input - <<EOF
{
  "wait_timer": 5,
  "reviewers": [
    {
      "type": "User",
      "id": YOUR_USER_ID
    }
  ],
  "deployment_branch_policy": {
    "protected_branches": true,
    "custom_branch_policies": false
  }
}
EOF
```

### 4. Test CI/CD Pipeline
```bash
# Create a test branch
git checkout -b test-deployment

# Make a small change
echo "# Test deployment" >> README.md
git add README.md
git commit -m "Test CI/CD pipeline"
git push origin test-deployment

# Create pull request
gh pr create --title "Test deployment" --body "Testing CI/CD pipeline"

# Check workflow status
gh run list
gh run view --log
```

## Domain and SSL Setup

### 1. Domain Configuration (Optional)
If you have a custom domain:

```bash
# Update terraform.tfvars in each environment
enable_custom_domain = true
domain_name = "yourdomain.com"
subdomain = "app"  # Results in app.yourdomain.com
```

### 2. SSL Certificate Setup
```bash
# Certificates are automatically provisioned via ACM
# Verify certificate status
aws acm list-certificates --region us-east-1
```

### 3. DNS Configuration
```bash
# If using Route53, DNS is configured automatically
# For external DNS providers, add CNAME records:
# app.yourdomain.com -> d1234567890.cloudfront.net
```

## Monitoring and Alerting Setup

### 1. Configure Notification Email
```bash
# Update terraform.tfvars
alarm_notification_email = "alerts@yourdomain.com"

# Apply changes
terraform apply
```

### 2. Subscribe to SNS Topics
```bash
# Get SNS topic ARNs
ALARM_TOPIC=$(terraform output -raw alarm_topic_arn)
COST_TOPIC=$(terraform output -raw cost_alert_topic_arn)

# Subscribe to notifications
aws sns subscribe --topic-arn "$ALARM_TOPIC" --protocol email --notification-endpoint "alerts@yourdomain.com"
aws sns subscribe --topic-arn "$COST_TOPIC" --protocol email --notification-endpoint "finance@yourdomain.com"
```

### 3. Configure Dashboards
```bash
# Dashboard URLs are available in Terraform outputs
terraform output monitoring_dashboard_url
terraform output security_dashboard_url
```

## Security Configuration

### 1. Enable Security Services
```bash
# Update terraform.tfvars for production
enable_guardduty = true
enable_security_hub = true
enable_config = true
enable_waf = true
```

### 2. Configure Security Notifications
```bash
# Security notifications are sent to the alarm topic
# Additional security-specific notifications can be configured
```

### 3. Review Security Policies
```bash
# Review IAM policies
aws iam list-policies --scope Local

# Review security group rules
aws ec2 describe-security-groups --group-names education-platform-*

# Review S3 bucket policies
aws s3api get-bucket-policy --bucket education-platform-*
```

## Backup and Recovery Setup

### 1. Verify Backup Configuration
```bash
# Check RDS automated backups
aws rds describe-db-clusters --query 'DBClusters[?contains(DBClusterIdentifier, `education-platform`)].{Cluster:DBClusterIdentifier,BackupRetention:BackupRetentionPeriod}'

# Check DynamoDB point-in-time recovery
aws dynamodb describe-continuous-backups --table-name education-platform-dev-*
```

### 2. Test Backup Restoration
```bash
# Create a test restore (in development environment)
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier education-platform-dev-marks-cluster \
  --db-cluster-identifier education-platform-dev-marks-cluster-restore-test \
  --restore-to-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S.000Z)
```

### 3. Document Recovery Procedures
Create a recovery runbook with step-by-step procedures for different disaster scenarios.

## Performance Optimization

### 1. Database Performance
```bash
# Enable Performance Insights (production)
enable_performance_insights = true

# Configure read replicas for read scaling
enable_read_replicas = true
read_replica_count = 2
```

### 2. CDN Optimization
```bash
# Configure CloudFront caching
cloudfront_default_ttl = 86400  # 1 day
cloudfront_max_ttl = 31536000   # 1 year

# Enable compression
enable_compression = true
```

### 3. Application Performance
```bash
# Configure Lambda memory and timeout
lambda_memory_size = 512
lambda_timeout = 30

# Enable X-Ray tracing
enable_xray_tracing = true
```

## Cost Optimization

### 1. Right-Sizing Resources
```bash
# Review CloudWatch metrics and right-size instances
# Use AWS Compute Optimizer recommendations

# Configure auto-scaling
enable_auto_scaling = true
min_capacity = 1
max_capacity = 10
```

### 2. Storage Optimization
```bash
# Configure S3 lifecycle policies
enable_lifecycle_policies = true

# Use Intelligent Tiering
enable_intelligent_tiering = true
```

### 3. Cost Monitoring
```bash
# Set up cost budgets
monthly_budget_limit = 1000  # USD

# Enable cost anomaly detection
enable_cost_anomaly_detection = true
```

## Troubleshooting

### Common Issues

#### 1. Terraform State Lock
```bash
# If Terraform state is locked
terraform force-unlock <lock-id>

# Check DynamoDB for lock table
aws dynamodb scan --table-name education-platform-terraform-locks
```

#### 2. Lambda Function Errors
```bash
# Check Lambda logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/education-platform"

# View specific function logs
aws logs filter-log-events --log-group-name "/aws/lambda/education-platform-dev-auth-handler" --start-time $(date -d '1 hour ago' +%s)000
```

#### 3. Database Connection Issues
```bash
# Check RDS cluster status
aws rds describe-db-clusters --db-cluster-identifier education-platform-dev-marks-cluster

# Check security group rules
aws ec2 describe-security-groups --group-names education-platform-dev-database-sg
```

#### 4. Frontend Deployment Issues
```bash
# Check S3 bucket contents
aws s3 ls s3://education-platform-dev-frontend-bucket/

# Check CloudFront distribution
aws cloudfront get-distribution --id E1234567890ABC
```

### Debug Commands
```bash
# Check AWS credentials
aws sts get-caller-identity

# Validate Terraform configuration
terraform validate

# Check resource status
terraform show

# View Terraform state
terraform state list

# Check GitHub Actions
gh run list --limit 10
gh run view <run-id> --log
```

### Log Analysis
```bash
# CloudWatch Logs Insights queries
aws logs start-query \
  --log-group-name "/aws/lambda/education-platform-dev-auth-handler" \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/'
```

## Maintenance Procedures

### Regular Maintenance Tasks

#### Weekly
- Review CloudWatch alarms and metrics
- Check security scan results
- Review cost reports and optimization opportunities
- Update dependencies and security patches

#### Monthly
- Review and rotate access keys
- Analyze performance metrics and optimize
- Review backup and recovery procedures
- Update documentation

#### Quarterly
- Conduct disaster recovery testing
- Review and update security policies
- Perform capacity planning
- Update architectural documentation

### Update Procedures

#### Infrastructure Updates
```bash
# Update Terraform modules
git pull origin main
cd terraform/environments/dev
terraform plan
terraform apply
```

#### Application Updates
```bash
# Updates are handled automatically via GitHub Actions
# Manual deployment if needed:
cd applications/frontend
npm run build
npm run deploy
```

## Support and Resources

### Documentation
- [Architecture Documentation](./ARCHITECTURE.md)
- [API Documentation](./API.md)
- [Troubleshooting Guide](./TROUBLESHOOTING.md)
- [Security Guide](./SECURITY.md)

### Monitoring Dashboards
- CloudWatch Dashboard: Available in Terraform outputs
- Application Performance: X-Ray console
- Cost Dashboard: AWS Cost Explorer
- Security Dashboard: AWS Security Hub

### Support Contacts
- **Technical Issues**: Create GitHub issue
- **Security Issues**: security@yourdomain.com
- **Infrastructure Issues**: infrastructure@yourdomain.com

### External Resources
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Security Best Practices](https://aws.amazon.com/security/security-resources/)

This deployment guide provides a comprehensive path from initial setup to production deployment. Follow the steps carefully and refer to the troubleshooting section if you encounter any issues.