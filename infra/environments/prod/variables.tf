variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-1"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "cloudmart"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}

variable "team_id" {
  description = "Your group ID for the Team= resource tag"
  type        = string
}

variable "owner_email" {
  description = "Contact email for the Owner= resource tag"
  type        = string
}

variable "custom_domain_name" {
  description = "Optional public frontend DNS name, for example cloudmart.example.com. Required for browser-trusted HTTPS."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Optional Route 53 hosted zone ID for custom_domain_name. When set with custom_domain_name, Terraform creates DNS validation and an ALB alias record."
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "Optional existing issued ACM certificate ARN for the frontend ALB. Use this if DNS validation is managed outside this Terraform."
  type        = string
  default     = ""
}

# --- Networking ---

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_data_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "cluster_name" {
  type    = string
  default = "cloudmart-prod"
}

variable "admin_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

# --- Database ---

variable "db_instance_class" {
  description = "RDS instance class — db.t3.micro is cheapest (see ADR-002)"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_backup_retention_period" {
  description = "RDS automated backup retention in days. Set to 0 for AWS Free Plan accounts that reject automated backups."
  type        = number
  default     = 7
}

variable "enable_guardduty" {
  description = "Enable GuardDuty threat detection when the AWS account plan supports it."
  type        = bool
  default     = true
}

# --- EKS ---

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes (see ADR-001)"
  type        = string
  default     = "t3.medium"
}

variable "node_min_count" {
  description = "Minimum worker nodes"
  type        = number
  default     = 2
}

variable "node_desired_count" {
  description = "Desired worker nodes"
  type        = number
  default     = 2
}

variable "node_max_count" {
  description = "Maximum worker nodes (for cluster autoscaler)"
  type        = number
  default     = 4
}

# --- SES ---

variable "ses_sender_email" {
  description = "Email address to verify in SES as the notification sender. After terraform apply, AWS sends a verification link — click it before switching EMAIL_BACKEND=ses."
  type        = string
  default     = "you@example.com"
}
