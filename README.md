# AWS Education Platform

A comprehensive, cloud-native education platform built on AWS featuring user authentication, real-time chat, video streaming, attendance tracking, marks management, and comprehensive monitoring.

##  Architecture Overview

### Core Services
- **Authentication**: AWS Cognito + API Gateway with JWT tokens
- **Static Hosting**: S3 + CloudFront for global content delivery
- **Chat System**: AppSync GraphQL + DynamoDB + OpenSearch for real-time messaging
- **Video Platform**: S3 + Elastic Transcoder + CloudFront for lecture streaming
- **Attendance**: Lambda functions + DynamoDB for tracking
- **Marks Management**: RDS Aurora PostgreSQL + EC2 + Application Load Balancer
- **Notifications**: SNS + SES for push and email notifications
- **Security**: WAF + IAM + KMS for comprehensive protection
- **Monitoring**: CloudWatch + CloudTrail + X-Ray for observability

### Architecture Principles
- **Serverless-First**: Leverages managed services for scalability
- **Microservices**: Loosely coupled services with clear boundaries
- **Security by Design**: Zero trust with encryption everywhere
- **High Availability**: Multi-AZ deployment with auto-scaling
- **Cost Optimized**: Pay-per-use model with auto-scaling

## Quick Start (15 minutes)

### Prerequisites
- AWS Account with administrative permissions
- AWS CLI installed and configured
- Terraform 1.5+
- Node.js 18+
- Git

### 1. Setup Environment
```bash
# Clone repository
git clone <your-repo-url>
cd AWS_Health_App

# Configure environment
cp .env.template .env
# Edit .env with your AWS Account ID and credentials
```

### 2. Install Dependencies
```bash
# Install all project dependencies
npm run install:all
```

### 3. Deploy Infrastructure
```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply  # Takes ~10-15 minutes
```

### 4. Deploy Applications
```bash
# Frontend is automatically deployed to S3/CloudFront
# Backend services deploy via Auto Scaling Groups
# Lambda functions deploy via Terraform
```

### 5. Access Your Platform
After deployment, Terraform outputs:
- **Website URL**: Your frontend application
- **API Gateway URL**: Backend API endpoint
- **Monitoring Dashboard**: CloudWatch dashboard

## 📁 Project Structure

```
aws-education-platform/
├── terraform/                    # Infrastructure as Code
│   ├── environments/            # Environment configs (dev/staging/prod)
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   ├── modules/                 # Reusable Terraform modules
│   │   ├── networking/          # VPC, subnets, security groups
│   │   ├── authentication/      # Cognito user pools
│   │   ├── chat/               # AppSync + DynamoDB
│   │   ├── video/              # S3 + Transcoder + CloudFront
│   │   ├── attendance/         # Lambda + DynamoDB
│   │   ├── marks/              # EC2 + RDS + ALB
│   │   ├── notifications/      # SNS + SES
│   │   ├── security/           # WAF + IAM + KMS
│   │   └── monitoring/         # CloudWatch + X-Ray
│   └── global/                 # Global resources (S3 backend, etc.)
├── applications/
│   ├── frontend/               # React application
│   │   ├── src/
│   │   ├── public/
│   │   └── package.json
│   ├── lambda-functions/       # Serverless functions
│   │   ├── auth/
│   │   ├── chat/
│   │   ├── attendance/
│   │   └── notifications/
│   └── backend-services/       # EC2-based services
│       └── marks-api/          # Node.js API for marks
├── .github/workflows/          # CI/CD pipelines
├── scripts/                    # Deployment and utility scripts
└── README.md                   # This file
```

## 🎯 Features by User Type

### Students
- ✅ Secure login with AWS Cognito
- ✅ View enrolled courses and schedules
- ✅ Access video lectures with streaming
- ✅ Participate in real-time chat discussions
- ✅ Track attendance automatically
- ✅ View marks and grades
- ✅ Receive push and email notifications

### Teachers
- ✅ Manage course content and materials
- ✅ Upload and manage video lectures
- ✅ Track student attendance in real-time
- ✅ Update marks and provide feedback
- ✅ Send announcements to students
- ✅ Monitor chat discussions

### Administrators
- ✅ Complete user management system
- ✅ System monitoring and analytics
- ✅ Security oversight and audit logs
- ✅ Performance metrics and dashboards
- ✅ Cost tracking and optimization

## 🔧 Configuration

### Environment Variables
Create `.env` file with:
```bash
# AWS Configuration
AWS_ACCOUNT_ID=123456789012
AWS_REGION=us-east-1
AWS_PROFILE=default

# Database
DB_USERNAME=admin
DB_PASSWORD=your-secure-password

# Domain (optional)
DOMAIN_NAME=your-domain.com

# GitHub (for CI/CD)
GITHUB_TOKEN=your-github-token
```

### Terraform Variables
Edit `terraform/environments/dev/terraform.tfvars`:
```hcl
aws_account_id = "123456789012"
aws_region     = "us-east-1"
environment    = "dev"
project_name   = "aws-education-platform"

# Database configuration
db_username = "admin"
db_password = "your-secure-password"

# Optional domain
domain_name = "your-domain.com"
```

## 🚀 Deployment Environments

### Development
- **Purpose**: Development and testing
- **Cost**: ~$50-100/month
- **Features**: All services with cost optimization
- **Auto-scaling**: Minimal instances

### Staging
- **Purpose**: Pre-production testing
- **Cost**: ~$100-200/month
- **Features**: Production-like environment
- **Auto-scaling**: Moderate scaling

### Production
- **Purpose**: Live system
- **Cost**: ~$200-500/month (varies by usage)
- **Features**: Full redundancy and monitoring
- **Auto-scaling**: Full scaling enabled

## 🔒 Security Features

- **Authentication**: Multi-factor authentication with AWS Cognito
- **Authorization**: Role-based access control (RBAC)
- **Encryption**: All data encrypted at rest and in transit
- **Network Security**: VPC isolation with security groups
- **Web Protection**: AWS WAF with DDoS protection
- **Monitoring**: CloudTrail for audit logs
- **Compliance**: GDPR and FERPA ready

## 📊 Monitoring & Observability

### CloudWatch Dashboards
- **Application Performance**: Response times, error rates
- **Infrastructure Health**: CPU, memory, disk usage
- **Cost Tracking**: Service-level cost breakdown
- **Security Metrics**: Failed logins, suspicious activity

### Alerting
- **Performance**: High latency or error rates
- **Security**: Unusual access patterns
- **Cost**: Budget threshold alerts
- **Infrastructure**: Service failures

## 💰 Cost Optimization

### Strategies Implemented
- **Serverless Services**: Pay only for usage
- **Auto Scaling**: Scale down during low usage
- **CloudFront Caching**: Reduce origin requests
- **S3 Lifecycle Policies**: Automatic archiving
- **Reserved Instances**: For predictable workloads
- **Spot Instances**: For non-critical workloads

### Estimated Monthly Costs
- **Development**: $50-100
- **Staging**: $100-200  
- **Production**: $200-500 (scales with usage)

## 🔧 Available Scripts

```bash
# Installation
npm run install:all              # Install all dependencies
npm run install:frontend         # Install frontend only
npm run install:backend          # Install backend only
npm run install:lambda-functions # Install Lambda dependencies

# Building
npm run build                    # Build frontend application

# Deployment
npm run deploy:dev              # Deploy to development
npm run deploy:staging          # Deploy to staging
npm run deploy:prod             # Deploy to production

# Terraform
npm run terraform:init          # Initialize Terraform
npm run terraform:plan          # Plan infrastructure changes
npm run terraform:apply         # Apply infrastructure changes
npm run terraform:destroy       # Destroy infrastructure

# Utilities
npm run setup:env              # Setup environment files
npm run verify:deployment      # Verify deployment status
```

##  Troubleshooting

### Common Issues

**Terraform Deployment Fails**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify permissions
aws iam get-user

# Check Terraform state
terraform state list
```

**Frontend Build Fails**
```bash
# Check Node.js version
node --version  # Should be 18+

# Clear cache and reinstall
rm -rf node_modules package-lock.json
npm install
```

**Database Connection Issues**
```bash
# Check security groups
aws ec2 describe-security-groups

# Verify RDS status
aws rds describe-db-instances
```

**Lambda Function Errors**
```bash
# Check CloudWatch logs
aws logs describe-log-groups
aws logs tail /aws/lambda/function-name
```

### Getting Help
1. Check CloudWatch logs for detailed error messages
2. Review Terraform plan output for infrastructure issues
3. Use the verification script: `npm run verify:deployment`
4. Check AWS service health dashboard

## CI/CD Pipeline

### GitHub Actions Workflows
- **Development**: Automatic deployment on push to `develop` branch
- **Staging**: Automatic deployment on push to `staging` branch  
- **Production**: Manual approval required for `main` branch
- **Testing**: Automated tests on all pull requests

### Pipeline Stages
1. **Code Quality**: Linting and formatting checks
2. **Security Scan**: Dependency and code security analysis
3. **Build**: Compile and package applications
4. **Test**: Unit and integration tests
5. **Deploy**: Infrastructure and application deployment
6. **Verify**: Post-deployment health checks

## 📝 Default Test Users

The system automatically creates test users:
- **Student**: `student@example.com` / `TempPassword123!`
- **Teacher**: `teacher@example.com` / `TempPassword123!`
- **Admin**: `admin@example.com` / `TempPassword123!`



## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

##  Support

For support and questions:
- Email: [your-email@domain.com]
- Documentation: Check this README
- Issues: Create a GitHub issue
- Discussions: Use GitHub Discussions

---

**🎉 Ready to transform education with AWS!** 
