# =============================================================================
# Remote State Backend
# IMPORTANT: Run the bootstrap module first, then paste the bucket name below.
#
# Get your account ID:
#   aws sts get-caller-identity --query Account --output text
#
# Then replace ACCOUNT-ID with the actual number.
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "cloudmart-terraform-state-AWS_ACCOUNT_ID"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cloudmart-terraform-locks"
    encrypt        = true
  }
}
