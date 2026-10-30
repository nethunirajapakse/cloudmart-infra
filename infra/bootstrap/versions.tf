terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
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
