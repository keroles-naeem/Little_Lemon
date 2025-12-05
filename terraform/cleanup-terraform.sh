#!/bin/bash
# cleanup-terraform.sh - Destroy the entire EKS cluster and AWS infrastructure
# WARNING: This will DELETE all AWS resources created by Terraform (VPC, EKS, nodes, etc.)
# Usage: ./cleanup-terraform.sh

set -e

echo "========================================="
echo "AWS Infrastructure Cleanup (Terraform)"
echo "========================================="
echo ""
echo "WARNING: This will PERMANENTLY DELETE:"
echo "  - EKS Cluster (little-lemon-cluster)"
echo "  - VPC and Subnets"
echo "  - NAT Gateways and Elastic IPs"
echo "  - Security Groups"
echo "  - IAM Roles"
echo "  - Load Balancers (if any remain)"
echo ""
echo "This action CANNOT be undone!"
read -p "Type 'destroy' to confirm permanent deletion: " confirm
if [ "$confirm" != "destroy" ]; then
  echo "Cleanup cancelled."
  exit 0
fi

cd ../terraform || { echo "Error: terraform directory not found"; exit 1; }

echo ""
echo "[1/2] Planning destruction..."
terraform plan -destroy -out=destroy.tfplan

echo ""
echo "[2/2] Applying destruction..."
read -p "Ready to destroy? Type 'yes' to confirm: " final
if [ "$final" != "yes" ]; then
  echo "Destruction cancelled."
  rm destroy.tfplan 2>/dev/null || true
  exit 0
fi

terraform apply destroy.tfplan
rm destroy.tfplan

echo ""
echo "========================================="
echo "AWS Infrastructure destroyed!"
echo "========================================="
echo ""
echo "To verify all resources are deleted:"
echo "  aws eks list-clusters --region us-east-1"
echo "  aws ec2 describe-vpcs --region us-east-1"
echo ""
