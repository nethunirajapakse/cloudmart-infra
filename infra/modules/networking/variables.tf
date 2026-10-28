variable "project" {
  description = "Project name — used as prefix for all resource names"
  type        = string
  default     = "cloudmart"
}

variable "environment" {
  description = "Deployment environment: prod or staging"
  type        = string

  validation {
    condition     = contains(["prod", "staging"], var.environment)
    error_message = "environment must be 'prod' or 'staging'."
  }
}

variable "aws_region" {
  description = "AWS region — used to construct VPC endpoint service names"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (must be /16 or larger per assignment)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to deploy subnets into (must have exactly 2)"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly 2 availability zones required."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets — one per AZ (e.g. ['10.0.1.0/24', '10.0.2.0/24'])"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets — one per AZ (e.g. ['10.0.11.0/24', '10.0.12.0/24'])"
  type        = list(string)
}

variable "private_data_subnet_cidrs" {
  description = "CIDR blocks for private data subnets — one per AZ (e.g. ['10.0.21.0/24', '10.0.22.0/24'])"
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS cluster name — used for Kubernetes subnet discovery tags"
  type        = string
  default     = "cloudmart-prod"
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH to the bastion host. Restrict to your IP (e.g. '1.2.3.4/32') in production."
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "Common tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}
