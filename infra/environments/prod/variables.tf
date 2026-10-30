variable "region" {
  description = "AWS region for this environment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name, used in the Environment tag and resource names"
  type        = string
  default     = "prod"
}

variable "team_id" {
  description = "Cost-allocation tag: team identifier"
  type        = string
  default     = "solo"
}

variable "owner_email" {
  description = "Cost-allocation tag: owner. Set in a gitignored terraform.auto.tfvars"
  type        = string
}
