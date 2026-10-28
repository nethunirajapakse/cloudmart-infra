variable "project" {
  description = "Project name"
  type        = string
  default     = "cloudmart"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.32"
}

variable "private_app_subnet_ids" {
  description = "Private application subnet IDs where worker nodes will run"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs included in the cluster VPC config (for ALB placement)"
  type        = list(string)
}

variable "eks_nodes_security_group_id" {
  description = "Security group ID for EKS worker nodes"
  type        = string
}

variable "rds_security_group_id" {
  description = "RDS security group ID — this module adds an ingress rule so Fargate pods can reach PostgreSQL on port 5432"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block — used to allow Fargate pod subnets to reach RDS on port 5432"
  type        = string
}

variable "kms_key_arn" {
  description = "Project KMS key ARN used to decrypt service-specific managed resources"
  type        = string
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes (see ADR-001 for selection rationale)"
  type        = string
  default     = "t3.medium"
}

variable "node_min_count" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_desired_count" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_max_count" {
  description = "Maximum number of worker nodes (for cluster autoscaler)"
  type        = number
  default     = 4
}

variable "ses_sender_email" {
  description = "Email address verified in SES as the notification sender (e.g. your real Gmail). AWS will send a verification link here after terraform apply."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
