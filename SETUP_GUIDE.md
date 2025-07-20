# AWS Education Platform - Setup Instructions

## 🚀 Quick Start Guide

This guide will help you set up and deploy the AWS Education Platform.

## Prerequisites

1. **AWS Account**: You need an AWS account with appropriate permissions
2. **AWS CLI**: Install and configure AWS CLI
   ```bash
   aws configure
   ```
3. **Terraform**: Install Terraform 1.5+
4. **Node.js**: Install Node.js 18+
5. **Git**: Install Git

## Step 1: Clone and Prepare the Repository

```bash
# Clone the repository
git clone https://github.com/your-org/aws-education-platform.git
cd aws-education-platform

# Copy environment files
cp .env.template .env
cd applications/frontend
cp .env.example .env.local
cd ../..
```

## Step 2: Configure AWS Credentials

1. Get your AWS Account ID:
   ```bash
   aws sts get-caller-identity --query Account --output text
   ```

2. Update the `.env` file with your AWS Account ID and other credentials

3. Set up AWS credentials:
   ```bash
   export AWS_PROFILE=your-profile-name
   export AWS_REGION=us-east-1
   ```

## Step 3: Bootstrap Terraform Backend

Run the bootstrap script to create S3 bucket and DynamoDB table for Terraform state:

```bash
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh dev
```

This will create:
- S3 bucket for Terraform state
- DynamoDB table for state locking
- Backend configuration files

## Step 4: Configure Terraform Variables

1. Navigate to the environment directory:
   ```bash
   cd terraform/environments/dev
   ```

2. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. Edit `terraform.tfvars` and replace:
   - `aws_account_id` with your actual AWS Account ID
   - Update any other values as needed

4. Update `backend.hcl` with your AWS Account ID

5. Set the database password:
   ```bash
   export TF_VAR_db_password="YourSecurePassword123!"
   ```

## Step 5: Deploy Infrastructure

1. Initialize Terraform:
   ```bash
   terraform init -backend-config=backend.hcl
   ```

2. Validate the configuration:
   ```bash
   terraform validate
   ```

3. Plan the deployment:
   ```bash
   terraform plan
   ```

4. Apply the configuration:
   ```bash
   terraform apply
   ```

   Type `yes` when prompted to confirm.

## Step 6: Deploy Applications

### Deploy Lambda Functions

```bash
cd applications/lambda-functions
for function in */; do
  cd "$function"
  npm install
  zip -r "../${function%/}.zip" .
  aws lambda update-function-code --function-name "education-platform-dev-${function%/}" --zip-file "fileb://../${function%/}.zip"
  cd ..
done
```

### Deploy Frontend

1. Get the deployment outputs:
   ```bash
   cd terraform/environments/dev
   terraform output -json > outputs.json
   ```

2. Update frontend configuration:
   ```bash
   cd applications/frontend
   # Update .env.local with values from terraform outputs
   ```

3. Build and deploy:
   ```bash
   npm install
   npm run build
   aws s3 sync build/ s3://$(terraform output -raw s3_bucket_name)/
   aws cloudfront create-invalidation --distribution-id $(terraform output -raw cloudfront_distribution_id) --paths "/*"
   ```

## Step 7: Verify Deployment

1. Access the website:
   ```bash
   echo "Website URL: $(terraform output -raw website_url)"
   ```

2. Check API Gateway:
   ```bash
   echo "API URL: $(terraform output -raw api_gateway_url)"
   ```

3. Monitor CloudWatch dashboards:
   ```bash
   echo "Monitoring Dashboard: $(terraform output -raw monitoring_dashboard_url)"
   ```

## Common Issues and Solutions

### Issue: Terraform state lock error
**Solution**: Check if another Terraform process is running or manually release the lock in DynamoDB.

### Issue: Permission denied errors
**Solution**: Ensure your AWS credentials have the necessary permissions. Use the provided IAM policy templates.

### Issue: Lambda function not working
**Solution**: Check CloudWatch logs for the specific function:
```bash
aws logs tail /aws/lambda/education-platform-dev-<function-name> --follow
```

### Issue: Frontend not loading
**Solution**: Check browser console for errors and verify API endpoints in `.env.local`

## Security Best Practices

1. **Never commit sensitive files**:
   - `.env`
   - `terraform.tfvars`
   - `*.pem` files
   - AWS credentials

2. **Use strong passwords**:
   - Database password should be at least 16 characters
   - Include uppercase, lowercase, numbers, and special characters

3. **Restrict access**:
   - Update `allowed_cidr_blocks` in production
   - Enable MFA on AWS accounts
   - Use least privilege IAM policies

4. **Regular updates**:
   - Keep dependencies updated
   - Apply security patches
   - Review CloudTrail logs

## Next Steps

1. **Set up CI/CD**:
   - Configure GitHub Actions secrets
   - Enable automated deployments

2. **Configure monitoring**:
   - Set up CloudWatch alarms
   - Configure email notifications

3. **Add custom domain**:
   - Register domain in Route53
   - Create SSL certificate
   - Update Terraform configuration

## Support

For issues or questions:
- Check the [documentation](docs/)
- Review [task completion files](TASK*_COMPLETED.md)
- Open an issue on GitHub

## Cleanup

To destroy all resources:
```bash
cd terraform/environments/dev
terraform destroy
```

**WARNING**: This will delete all resources including data. Make sure to backup any important data first.
