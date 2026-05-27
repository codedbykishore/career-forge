#!/bin/bash

# CareerForge Deployment Script
# Deploys backend to Elastic Beanstalk and frontend to S3 + CloudFront

set -euo pipefail

# Configuration
PROJECT_ROOT="/home/kinux/projects/career-forge"
BACKEND_DIR="$PROJECT_ROOT/project/backend"
FRONTEND_DIR="$PROJECT_ROOT/project/frontend"
DEPLOY_DIR="$PROJECT_ROOT/deployment"

# AWS Configuration
AWS_REGION="us-east-1"
S3_BUCKET_NAME="careerforge-frontend-$(aws sts get-caller-identity --query Account --output text)"
DOMAIN_NAME="careerforge.example.com"
CERTIFICATE_ARN="arn:aws:acm:us-east-1:$(aws sts get-caller-identity --query Account --output text):certificate/12345678-1234-1234-1234-123456789012"
EB_APPLICATION_NAME="careerforge-backend"
EB_ENVIRONMENT_NAME="careerforge-prod"

# Check AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install and configure it first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "AWS credentials are not configured. Please run 'aws configure'."
    exit 1
fi

# Check required directories exist
if [ ! -d "$BACKEND_DIR" ]; then
    echo "Backend directory not found: $BACKEND_DIR"
    exit 1
fi

if [ ! -d "$FRONTEND_DIR" ]; then
    echo "Frontend directory not found: $FRONTEND_DIR"
    exit 1
fi

# Check for required files
if [ ! -f "$BACKEND_DIR/requirements.txt" ]; then
    echo "requirements.txt not found in backend directory"
    exit 1
fi

if [ ! -f "$FRONTEND_DIR/package.json" ]; then
    echo "package.json not found in frontend directory"
    exit 1
fi

# Create deployment package for backend
echo "Creating backend deployment package..."
BACKEND_PACKAGE="/tmp/careerforge-backend.zip"
rm -f "$BACKEND_PACKAGE"
cd "$BACKEND_DIR" && zip -r "$BACKEND_PACKAGE" . -x "*.git/*" "venv/*" "*.log" "*.tmp" "*.pyc" "__pycache__/*" "*.env" "*.example" "*.md" "*.html" "*.json" "*.yaml" "*.yml" "*.png" "*.jpg" "*.jpeg" "*.gif" "*.svg" "*.ico" "*.pdf" "*.zip" "*.tar" "*.gz" "*.bz2" "*.xz" "*.7z" "*.dmg" "*.exe" "*.msi" "*.app" "*.bin" "*.dat" "*.db" "*.sqlite" "*.log" "*.tmp" "*.cache" "*.lock" "*.swp" "*.swo" "*.swn" "*.DS_Store" "Thumbs.db"

# Create deployment package for frontend
echo "Building frontend application..."
FRONTEND_BUILD_DIR="/tmp/careerforge-frontend"
rm -rf "$FRONTEND_BUILD_DIR"
mkdir -p "$FRONTEND_BUILD_DIR"
cd "$FRONTEND_DIR" && npm install && npm run build
rsync -av --delete "$FRONTEND_DIR/dist/" "$FRONTEND_BUILD_DIR/"

# Create deployment package for frontend
FRONTEND_PACKAGE="/tmp/careerforge-frontend.zip"
rm -f "$FRONTEND_PACKAGE"
cd "$FRONTEND_BUILD_DIR" && zip -r "$FRONTEND_PACKAGE" .

# Deploy backend to Elastic Beanstalk
echo "Deploying backend to Elastic Beanstalk..."
EB_VERSION_LABEL="backend-$(date +%Y%m%d-%H%M%S)"

# Create application if it doesn't exist
if ! aws elasticbeanstalk describe-applications --application-names "$EB_APPLICATION_NAME" --query 'Applications[0].ApplicationName' --output text 2>/dev/null | grep -q "$EB_APPLICATION_NAME"; then
    echo "Creating Elastic Beanstalk application: $EB_APPLICATION_NAME"
    aws elasticbeanstalk create-application --application-name "$EB_APPLICATION_NAME" --description "CareerForge Backend API"
fi

# Create application version
aws elasticbeanstalk create-application-version \
    --application-name "$EB_APPLICATION_NAME" \
    --version-label "$EB_VERSION_LABEL" \
    --source-bundle S3Bucket="careerforge-deployment",S3Key="backend/$EB_VERSION_LABEL.zip" \
    --auto-create-application

# Upload deployment package to S3
aws s3 cp "$BACKEND_PACKAGE" "s3://careerforge-deployment/backend/$EB_VERSION_LABEL.zip"

# Update environment with new version
if aws elasticbeanstalk describe-environments --application-name "$EB_APPLICATION_NAME" --environment-names "$EB_ENVIRONMENT_NAME" --query 'Environments[0].EnvironmentName' --output text 2>/dev/null | grep -q "$EB_ENVIRONMENT_NAME"; then
    echo "Updating existing environment: $EB_ENVIRONMENT_NAME"
    aws elasticbeanstalk update-environment \
        --application-name "$EB_APPLICATION_NAME" \
        --environment-name "$EB_ENVIRONMENT_NAME" \
        --version-label "$EB_VERSION_LABEL"
else
    echo "Creating new environment: $EB_ENVIRONMENT_NAME"
    aws elasticbeanstalk create-environment \
        --application-name "$EB_APPLICATION_NAME" \
        --environment-name "$EB_ENVIRONMENT_NAME" \
        --solution-stack-name "64bit Amazon Linux 2 v5.7.0 running Python 3.12" \
        --version-label "$EB_VERSION_LABEL" \
        --option-settings file://"$DEPLOY_DIR/backend/elastic-beanstalk.config"
fi

# Deploy frontend to S3 + CloudFront
echo "Deploying frontend to S3..."

# Create S3 bucket if it doesn't exist
if ! aws s3api head-bucket --bucket "$S3_BUCKET_NAME" 2>/dev/null; then
    echo "Creating S3 bucket: $S3_BUCKET_NAME"
    aws s3api create-bucket --bucket "$S3_BUCKET_NAME" --region "$AWS_REGION" --create-bucket-configuration LocationConstraint="$AWS_REGION"
fi

# Sync frontend files to S3
aws s3 sync "$FRONTEND_BUILD_DIR" "s3://$S3_BUCKET_NAME" --delete --cache-control "max-age=86400"

# Invalidate CloudFront cache
CLOUDFRONT_DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='CareerForge Frontend Distribution'].Id" --output text)
if [ -n "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
    echo "Invalidating CloudFront cache..."
    aws cloudfront create-invalidation --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" --paths "/*"
else
    echo "CloudFront distribution not found. Deploying CloudFront stack..."
    # Create CloudFront stack
    aws cloudformation create-stack \
        --stack-name "careerforge-frontend" \
        --template-body file://"$DEPLOY_DIR/frontend/s3-cloudfront.yml" \
        --parameters ParameterKey=DomainName,ParameterValue="$DOMAIN_NAME" ParameterKey=CertificateArn,ParameterValue="$CERTIFICATE_ARN" \
        --capabilities CAPABILITY_IAM
fi

# Wait for deployment to complete
if [ -n "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
    echo "Deployment completed successfully!"
    echo "Backend: https://$(aws elasticbeanstalk describe-environments --application-name "$EB_APPLICATION_NAME" --environment-names "$EB_ENVIRONMENT_NAME" --query 'Environments[0].EndpointURL' --output text)"
    echo "Frontend: https://$DOMAIN_NAME"
else
    echo "Deployment completed successfully!"
    echo "Backend: https://$(aws elasticbeanstalk describe-environments --application-name "$EB_APPLICATION_NAME" --environment-names "$EB_ENVIRONMENT_NAME" --query 'Environments[0].EndpointURL' --output text)"
    echo "Frontend: https://$DOMAIN_NAME"
fi

# Clean up temporary files
rm -f "$BACKEND_PACKAGE" "$FRONTEND_PACKAGE"
rm -rf "$FRONTEND_BUILD_DIR"

# Print next steps
echo "\nNext Steps:" 
echo "1. Update DNS records to point $DOMAIN_NAME to CloudFront distribution"
echo "2. Configure AWS Secrets Manager with environment variables"
echo "3. Set up DynamoDB tables if not already created"
echo "4. Configure SES for email sending"
echo "5. Configure AWS Cognito for authentication (if needed)"