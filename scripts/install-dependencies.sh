#!/bin/bash

# AWS Education Platform - Install Dependencies
# Cross-platform script to install all project dependencies

set -e

echo "🚀 Installing AWS Education Platform Dependencies..."
echo "=================================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command_exists node; then
    echo "❌ Node.js is not installed. Please install Node.js 18+ from https://nodejs.org/"
    exit 1
fi

if ! command_exists npm; then
    echo "❌ npm is not installed. Please install npm."
    exit 1
fi

echo "✅ Node.js and npm are installed"

# Install root dependencies
echo "📦 Installing root dependencies..."
npm install

# Install frontend dependencies
echo "📦 Installing frontend dependencies..."
cd applications/frontend
npm install
cd ../..

# Install backend dependencies
echo "📦 Installing backend dependencies..."
cd applications/backend-services/marks-api
npm install
cd ../../..

# Install Lambda function dependencies
echo "📦 Installing Lambda function dependencies..."
cd applications/lambda-functions

for dir in */; do
    if [ -f "${dir}package.json" ]; then
        echo "  Installing dependencies for ${dir%/}..."
        cd "$dir"
        npm install
        cd ..
    fi
done

cd ../..

# Install test dependencies
echo "📦 Installing test dependencies..."
cd tests
npm install
cd ..

echo ""
echo "✅ All dependencies installed successfully!"
echo ""
echo "Next steps:"
echo "1. Copy .env.template to .env and configure your environment"
echo "2. Configure AWS credentials: aws configure"
echo "3. Initialize Terraform: cd terraform/environments/dev && terraform init"
echo "4. Deploy infrastructure: terraform plan && terraform apply"
