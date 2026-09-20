#!/bin/bash
ENV="${1:-dev}"

echo "Running in environment: $ENV"

VAR_FILE="./variables/${ENV}.tfvars"
VAR_CONFIG="./environments/${ENV}.backend.hcl"

echo "VAR_FILE: $VAR_FILE"
echo "VAR_CONFIG: $VAR_CONFIG"

# Initialize Terraform
terraform init -reconfigure -backend-config="$VAR_CONFIG"

terraform workspace select "${ENV}" 2>/dev/null || terraform workspace new "${ENV}"
terraform workspace show


# Validate the configuration
terraform validate

# Plan and apply the Terraform project
terraform plan -var-file="$VAR_FILE"  -out=tfplan
