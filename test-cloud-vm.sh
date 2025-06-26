#!/bin/bash

# Test script for cloud_vm module
# This script provides step-by-step testing commands

set -e # Exit on any error

echo "🧪 Testing Cloud VM Module"
echo "=========================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check if Terraform is installed
if command -v terraform &>/dev/null; then
    print_status "Terraform is installed"
    terraform version
else
    print_error "Terraform is not installed"
    exit 1
fi

# Check if gcloud is installed and authenticated
if command -v gcloud &>/dev/null; then
    print_status "gcloud CLI is installed"

    # Check authentication
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_status "gcloud is authenticated"
        gcloud config get-value project
    else
        print_error "gcloud is not authenticated. Run: gcloud auth login"
        exit 1
    fi
else
    print_error "gcloud CLI is not installed"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "test-cloud-vm.tf" ]; then
    print_error "test-cloud-vm.tf not found. Make sure you're in the project root directory."
    exit 1
fi

echo ""
echo "🔧 Configuration Steps:"
echo "======================"

print_warning "1. Update test-cloud-vm.tf with your actual project ID"
print_warning "2. Update the MLflow image URI in test-cloud-vm.tf"
print_warning "3. Make sure the artifact bucket name is globally unique"

echo ""
echo "🧪 Testing Commands:"
echo "==================="

echo ""
echo "1. Validate Terraform configuration:"
echo "   terraform init"
echo "   terraform validate"

echo ""
echo "2. Plan the deployment (dry run):"
echo "   terraform plan -var-file=test-cloud-vm.tfvars"

echo ""
echo "3. Apply the deployment:"
echo "   terraform apply -var-file=test-cloud-vm.tfvars"

echo ""
echo "4. Test the deployment:"
echo "   # Get the MLflow URL from terraform output"
echo "   terraform output test_mlflow_url"
echo "   # SSH into the VM"
echo "   terraform output test_ssh_command"

echo ""
echo "5. Clean up:"
echo "   terraform destroy -var-file=test-cloud-vm.tfvars"

echo ""
echo "🚀 Alternative: Test via DeployML CLI"
echo "===================================="
echo "1. Update test-cloud-vm.yaml with your project details"
echo "2. Run: poetry run deployml deploy --config-path test-cloud-vm.yaml"
echo "3. Run: poetry run deployml destroy --config-path test-cloud-vm.yaml"

echo ""
print_warning "⚠️  Remember to replace 'your-project-id' with your actual GCP project ID!"
print_warning "⚠️  Make sure the artifact bucket name is globally unique!"
print_warning "⚠️  Consider using a smaller machine type (e2-small) for testing to save costs!"
