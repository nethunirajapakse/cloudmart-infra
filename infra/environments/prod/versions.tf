terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Partial backend configuration: the bucket name is supplied at init time
  # with -backend-config=backend.hcl so the account ID stays out of git.
  backend "s3" {
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # native S3 state locking (Terraform >= 1.10)
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "cloudmart"
      Environment = var.environment
      Team        = var.team_id
      Owner       = var.owner_email
      ManagedBy   = "terraform"
    }
  }
}
