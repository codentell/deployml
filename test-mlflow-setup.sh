#!/bin/bash

# Test script for MLflow setup on VM
# Run this after deploying the VM to verify MLflow is working

set -e

echo "🧪 Testing MLflow Setup on VM"
echo "============================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Get VM IP from terraform output
VM_IP=$(terraform output -raw test_vm_external_ip 2>/dev/null || echo "")

if [ -z "$VM_IP" ]; then
    print_error "Could not get VM IP from terraform output"
    print_warning "Make sure you've run: terraform apply -var-file=test-cloud-vm.tfvars"
    exit 1
fi

print_status "VM IP: $VM_IP"

echo ""
echo "🔍 Testing MLflow connectivity..."

# Test if MLflow is responding
echo "Testing MLflow UI at http://$VM_IP:5000..."

# Wait a bit for MLflow to fully start
sleep 5

# Test HTTP response
if curl -s -f "http://$VM_IP:5000" >/dev/null; then
    print_status "MLflow UI is accessible!"
    echo "🌐 Open your browser to: http://$VM_IP:5000"
else
    print_warning "MLflow UI not responding yet..."
    echo "This might be normal if MLflow is still starting up."
    echo "You can SSH into the VM to check the status:"
    echo "  gcloud compute ssh test-mlflow-vm --zone=us-west1-a"
    echo ""
    echo "Then check MLflow status with:"
    echo "  sudo systemctl status mlflow"
    echo "  sudo journalctl -u mlflow -f"
fi

echo ""
echo "🔧 Manual verification steps:"
echo "1. SSH into the VM:"
echo "   gcloud compute ssh test-mlflow-vm --zone=us-west1-a"
echo ""
echo "2. Check MLflow service status:"
echo "   sudo systemctl status mlflow"
echo ""
echo "3. Check MLflow logs:"
echo "   sudo journalctl -u mlflow -f"
echo ""
echo "4. Test MLflow locally on VM:"
echo "   curl http://localhost:5000"
echo ""
echo "5. Check environment:"
echo "   source /home/debian/mlflow-env/bin/activate"
echo "   mlflow --version"

echo ""
print_warning "Remember to clean up when done:"
echo "  terraform destroy -var-file=test-cloud-vm.tfvars"
