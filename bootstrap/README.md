# Terraform State Management Bootstrap

This directory contains the Terraform configuration to set up the necessary infrastructure for managing Terraform state remotely.

## Resources Created

1. **S3 Bucket**
   - Versioning enabled
   - Server-side encryption enabled
   - Public access blocked
   - TLS enforcement policy

2. **DynamoDB Table**
   - Used for state locking
   - Pay-per-request billing
   - LockID as primary key

## Usage

```bash
# Initialize Terraform
terraform init

# Review changes
terraform plan

# Apply changes
terraform apply

# Note the outputs for use in main configuration
terraform output
```

## Security Features

- Enforced TLS for all requests
- Server-side encryption
- No public access
- Versioning enabled for audit trail
- State locking to prevent concurrent modifications

## Important Notes

- The S3 bucket name must be globally unique
- The `prevent_destroy` lifecycle rule is enabled for the S3 bucket
- Remember to update the main Terraform configuration with the outputs from this bootstrap