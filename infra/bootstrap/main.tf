# =============================================================================
# CloudMart Bootstrap
# Run this ONCE before anything else.
# Creates the S3 bucket + DynamoDB table used as the Terraform remote backend.
# This module intentionally uses local state (the chicken-and-egg problem).
# =============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # No backend block here — state stays local (bootstrap only runs once)
}

provider "aws" {
  region = var.region
}

# --- S3 Bucket for Terraform State ---

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project}-terraform-state-${var.account_id}"

  lifecycle {
    prevent_destroy = true # Safety: prevents accidental state loss
  }

  tags = {
    Name      = "${var.project}-terraform-state"
    Project   = var.project
    ManagedBy = "terraform-bootstrap"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled" # Allows recovery of previous state files
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- DynamoDB Table for State Locking ---

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST" # Free for low usage
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "${var.project}-terraform-locks"
    Project   = var.project
    ManagedBy = "terraform-bootstrap"
  }
}
