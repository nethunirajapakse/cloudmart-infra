variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "staging"
}

variable "team_id" {
  description = "Your group ID for resource tagging"
  type        = string
}

variable "owner_email" {
  description = "Contact email for resource tagging"
  type        = string
}

# These variables document how a fully isolated staging stack would differ.
# They are not used by the normal namespace-based staging deployment.
variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.11.0/24", "10.1.12.0/24"]
}

variable "private_data_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.21.0/24", "10.1.22.0/24"]
}

variable "cluster_name" {
  type    = string
  default = "cloudmart-prod"
}

variable "admin_cidr" {
  type    = string
  default = "0.0.0.0/0"
}
