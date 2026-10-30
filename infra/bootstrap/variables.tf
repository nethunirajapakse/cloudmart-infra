variable "region" {
  description = "AWS region for the state bucket"
  type        = string
  default     = "us-east-1"
}

variable "team_id" {
  description = "Cost-allocation tag: team identifier"
  type        = string
  default     = "solo"
}

variable "owner_email" {
  description = "Cost-allocation tag: owner. No default; pass with -var or a gitignored *.auto.tfvars"
  type        = string
}
