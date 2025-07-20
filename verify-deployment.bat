@echo off
echo AWS Education Platform - Deployment Verification
echo ================================================

cd terraform\environments\dev

echo.
echo Step 1: Validating Terraform configuration...
terraform validate
if %errorlevel% neq 0 (
    echo ERROR: Terraform validation failed
    pause
    exit /b 1
)
echo Terraform validation passed ✓

echo.
echo Step 2: Checking Terraform plan...
terraform plan -out=tfplan
if %errorlevel% neq 0 (
    echo ERROR: Terraform plan failed
    pause
    exit /b 1
)
echo Terraform plan completed ✓

echo.
echo Step 3: Checking for common issues...

REM Check if backend is initialized
if not exist ".terraform" (
    echo WARNING: Terraform not initialized
    echo Run: terraform init -backend-config=backend.hcl
)

REM Check if AWS credentials are set
aws sts get-caller-identity >nul 2>&1
if %errorlevel% neq 0 (
    echo WARNING: AWS credentials not configured
    echo Run: aws configure
)

REM Check if database password is set
if "%TF_VAR_db_password%"=="" (
    echo WARNING: Database password not set
    echo Run: set TF_VAR_db_password=YourSecurePassword123!
)

echo.
echo ================================================
echo Verification Complete!
echo ================================================
echo If no errors above, you can deploy with:
echo terraform apply tfplan
echo ================================================

cd ..\..\..
pause