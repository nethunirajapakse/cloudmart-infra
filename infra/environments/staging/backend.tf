# =============================================================================
# Optional Remote State Backend for Staging Metadata
#
# Normal staging deployment is Kubernetes-only: k8s/overlays/staging is applied
# to the shared cloudmart-prod EKS cluster. This backend is kept only if you
# want separate Terraform state for staging metadata later.
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "cloudmart-terraform-state-AWS_ACCOUNT_ID"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cloudmart-terraform-locks"
    encrypt        = true
  }
}
