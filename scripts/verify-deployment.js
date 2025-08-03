#!/usr/bin/env node

/**
 * AWS Education Platform - Deployment Verification Script
 * 
 * This script verifies that all required tools and configurations
 * are in place for deploying the education platform.
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

console.log('========================================');
console.log('AWS Education Platform - Deployment Verification');
console.log('========================================\n');

let hasErrors = false;

/**
 * Check if a command exists
 */
function checkCommand(command, name) {
  try {
    execSync(`${command} --version`, { stdio: 'pipe' });
    console.log(`[OK] ${name} is installed`);
    return true;
  } catch (error) {
    console.log(`[ERROR] ${name} is not installed or not in PATH`);
    hasErrors = true;
    return false;
  }
}

/**
 * Check if a file exists
 */
function checkFile(filePath, description) {
  if (fs.existsSync(filePath)) {
    console.log(`[OK] ${description} exists`);
    return true;
  } else {
    console.log(`[ERROR] ${description} not found at ${filePath}`);
    hasErrors = true;
    return false;
  }
}

/**
 * Check environment variables
 */
function checkEnvVars() {
  const requiredVars = [
    'AWS_ACCOUNT_ID',
    'AWS_REGION'
  ];

  const optionalVars = [
    'DOMAIN_NAME',
    'DB_USERNAME',
    'DB_PASSWORD'
  ];

  console.log('\nChecking environment variables...');
  
  requiredVars.forEach(varName => {
    if (process.env[varName]) {
      console.log(`[OK] ${varName} is set`);
    } else {
      console.log(`[ERROR] Required environment variable ${varName} is not set`);
      hasErrors = true;
    }
  });

  optionalVars.forEach(varName => {
    if (process.env[varName]) {
      console.log(`[OK] ${varName} is set`);
    } else {
      console.log(`[WARN] Optional environment variable ${varName} is not set`);
    }
  });
}

/**
 * Main verification function
 */
function main() {
  console.log('Checking required tools...');
  
  // Check required tools
  checkCommand('terraform', 'Terraform');
  checkCommand('node', 'Node.js');
  checkCommand('npm', 'npm');
  checkCommand('aws', 'AWS CLI');
  
  console.log('\nChecking project structure...');
  
  // Check project files
  const projectRoot = path.join(__dirname, '..');
  checkFile(path.join(projectRoot, 'package.json'), 'Root package.json');
  checkFile(path.join(projectRoot, 'terraform', 'environments', 'dev', 'main.tf'), 'Dev Terraform configuration');
  checkFile(path.join(projectRoot, 'applications', 'frontend', 'package.json'), 'Frontend package.json');
  
  // Check environment variables
  checkEnvVars();
  
  console.log('\nChecking AWS credentials...');
  try {
    execSync('aws sts get-caller-identity', { stdio: 'pipe' });
    console.log('[OK] AWS credentials are configured');
  } catch (error) {
    console.log('[ERROR] AWS credentials are not configured or invalid');
    hasErrors = true;
  }
  
  console.log('\nChecking Terraform state...');
  const terraformDir = path.join(projectRoot, 'terraform', 'environments', 'dev');
  try {
    process.chdir(terraformDir);
    execSync('terraform version', { stdio: 'pipe' });
    console.log('[OK] Terraform is working in dev environment');
  } catch (error) {
    console.log('[ERROR] Terraform configuration issue in dev environment');
    hasErrors = true;
  }
  
  console.log('\n========================================');
  if (hasErrors) {
    console.log('[FAILED] Deployment verification failed. Please fix the errors above.');
    process.exit(1);
  } else {
    console.log('[SUCCESS] All checks passed! Ready for deployment.');
    process.exit(0);
  }
}

// Run the verification
main();
