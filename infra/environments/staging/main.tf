# =============================================================================
# CloudMart Staging Environment
#
# Staging shares the prod VPC, EKS cluster, and managed services.
# The assignment staging boundary is the cloudmart-staging Kubernetes namespace.
# This Terraform environment demonstrates environment variable parameterization.
#
# Normal staging deployment:
#   1. Apply infra/environments/prod
#   2. Deploy k8s/overlays/staging to the cloudmart-staging namespace
#
# Do not apply this staging Terraform directory for the normal assignment flow.
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = "cloudmart"
    Environment = var.environment
    Team        = var.team_id
    Owner       = var.owner_email
    ManagedBy   = "terraform"
  }
}

# Staging uses the same AWS infrastructure as prod in this assignment.
# If a future production project needs isolated staging infrastructure, create a
# separate stack here with non-overlapping CIDRs and separate managed services.
