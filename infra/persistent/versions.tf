terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Bucket supplied at init time: terraform init -backend-config=backend.hcl
  backend "s3" {
    key          = "persistent/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "cloudmart"
      Environment = "shared"
      Team        = var.team_id
      Owner       = var.owner_email
      ManagedBy   = "terraform"
    }
  }
}
