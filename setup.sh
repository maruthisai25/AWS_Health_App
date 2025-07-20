#!/bin/bash

# AWS Education Platform - Quick Start Script
# This script helps set up the initial project structure

echo "🎓 AWS Education Platform Setup"
echo "=============================="

# Check prerequisites
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 is not installed. Please install it first."
        exit 1
    else
        echo "✅ $1 is installed"
    fi
}

echo ""
echo "Checking prerequisites..."
check_command terraform
check_command node
check_command npm
check_command aws
check_command git

# Create directory structure
echo ""
echo "Creating project structure..."

# Terraform directories
mkdir -p terraform/{modules/{networking,authentication,chat,video,attendance,marks,notifications,security,monitoring,static-hosting},environments/{dev,staging,prod},global}

# Application directories
mkdir -p applications/{frontend/{src/{components,pages,services},public},lambda-functions/{auth-handler,chat-resolver,video-processor,attendance-tracker,attendance-reporter,notification-handler,email-sender},backend-services/marks-api/{migrations,src}}

# Other directories
mkdir -p {.github/workflows,tests/{integration,e2e},scripts,docs}

echo "✅ Directory structure created"

# Create .gitignore
echo ""
echo "Creating .gitignore..."
cat > .gitignore << 'EOF'
# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
terraform.tfvars
*.auto.tfvars

# Environment
.env
.env.*
!.env.template

# Node
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.npm

# Build outputs
dist/
build/
*.zip
*.tar.gz

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# AWS
.aws-sam/
samconfig.toml

# Logs
logs/
*.log

# Testing
coverage/
.nyc_output/

# Secrets
*.pem
*.key
*.cer
*.crt
*.p12
EOF

echo "✅ .gitignore created"

# Initialize git repository
if [ ! -d .git ]; then
    echo ""
    echo "Initializing git repository..."
    git init
    git add .
    git commit -m "Initial commit: Project structure"
    echo "✅ Git repository initialized"
fi

# Copy environment template
if [ ! -f .env ]; then
    echo ""
    echo "Creating .env from template..."
    cp .env.template .env
    echo "⚠️  Please edit .env file with your actual credentials"
fi

# Create initial Terraform backend configuration
echo ""
echo "Creating Terraform backend configuration..."
cat > terraform/backend.tf << 'EOF'
# This file will be populated by Task 1
# Placeholder for S3 backend configuration
EOF

# Create package.json for the frontend
echo ""
echo "Creating frontend package.json..."
cat > applications/frontend/package.json << 'EOF'
{
  "name": "education-platform-frontend",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.8.0",
    "aws-amplify": "^5.0.0",
    "@aws-amplify/ui-react": "^4.0.0"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "devDependencies": {
    "react-scripts": "5.0.1"
  }
}
EOF

echo "✅ Frontend package.json created"

echo ""
echo "🎉 Setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit .env file with your AWS credentials"
echo "2. Review tasks.md for implementation tasks"
echo "3. Start with Task 1 to create base infrastructure"
echo ""
echo "To implement a task:"
echo "- Copy the task content from tasks.md"
echo "- Provide it to your LLM to generate the code"
echo "- Save the generated files in the appropriate directories"
echo ""
echo "Happy coding! 🚀"
