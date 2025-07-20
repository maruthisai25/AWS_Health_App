@echo off
echo AWS Education Platform - Environment Setup
echo ==========================================

echo.
echo Step 1: Checking AWS CLI installation...
aws --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: AWS CLI is not installed or not in PATH
    echo Please install AWS CLI from: https://aws.amazon.com/cli/
    echo Then configure it with: aws configure
    pause
    exit /b 1
)

echo AWS CLI is installed ✓

echo.
echo Step 2: Getting AWS Account ID...
for /f %%i in ('aws sts get-caller-identity --query Account --output text 2^>nul') do set AWS_ACCOUNT_ID=%%i

if "%AWS_ACCOUNT_ID%"=="" (
    echo ERROR: Could not get AWS Account ID
    echo Please run: aws configure
    echo And ensure you have valid AWS credentials
    pause
    exit /b 1
)

echo AWS Account ID: %AWS_ACCOUNT_ID% ✓

echo.
echo Step 3: Updating configuration files...

REM Update terraform.tfvars
powershell -Command "(Get-Content 'terraform\environments\dev\terraform.tfvars') -replace 'YOUR_ACTUAL_ACCOUNT_ID', '%AWS_ACCOUNT_ID%' | Set-Content 'terraform\environments\dev\terraform.tfvars'"

REM Update backend.hcl
powershell -Command "(Get-Content 'terraform\environments\dev\backend.hcl') -replace 'YOUR_ACTUAL_ACCOUNT_ID', '%AWS_ACCOUNT_ID%' | Set-Content 'terraform\environments\dev\backend.hcl'"

echo Configuration files updated ✓

echo.
echo Step 4: Installing Lambda dependencies...
call install-lambda-deps.bat

echo.
echo Step 5: Setting up environment variables...
echo Please set the database password:
echo set TF_VAR_db_password=YourSecurePassword123!
echo.
echo Or add it to your environment permanently:
echo setx TF_VAR_db_password "YourSecurePassword123!"

echo.
echo ==========================================
echo Setup Complete! Next steps:
echo ==========================================
echo 1. Set database password: set TF_VAR_db_password=YourSecurePassword123!
echo 2. Navigate to terraform: cd terraform\environments\dev
echo 3. Initialize Terraform: terraform init -backend-config=backend.hcl
echo 4. Plan deployment: terraform plan
echo 5. Deploy infrastructure: terraform apply
echo ==========================================

pause