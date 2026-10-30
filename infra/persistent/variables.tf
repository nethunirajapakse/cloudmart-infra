variable "region" {
  type    = string
  default = "us-east-1"
}

variable "team_id" {
  type    = string
  default = "solo"
}

variable "owner_email" {
  description = "Cost-allocation tag: owner. Set in a gitignored terraform.auto.tfvars"
  type        = string
}

variable "services" {
  description = "Services that each get an ECR repository"
  type        = list(string)
  default = [
    "frontend",
    "product-service",
    "order-service",
    "user-service",
    "notification-service",
  ]
}

variable "environments" {
  description = "Environments that each get their own table and queue"
  type        = list(string)
  default     = ["prod", "staging"]
}
