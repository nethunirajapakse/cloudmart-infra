variable "region" {
  description = "AWS region where the state bucket will be created"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name — used as a prefix for bucket and table names"
  type        = string
  default     = "cloudmart"
}

variable "account_id" {
  description = "Your AWS Account ID — makes the S3 bucket name globally unique. Run: aws sts get-caller-identity --query Account --output text"
  type        = string
}
