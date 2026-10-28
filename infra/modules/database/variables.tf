variable "project" {
  description = "Project name"
  type        = string
  default     = "cloudmart"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "private_data_subnet_ids" {
  description = "Private data subnet IDs where RDS will be placed"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "Security group ID for RDS (allows port 5432 from EKS nodes only)"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting RDS storage, DynamoDB, and Secrets Manager"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class (db.t3.micro = smallest/cheapest)"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_backup_retention_period" {
  description = "Automated backup retention in days. Use 0 for AWS Free Plan accounts that reject automated backups."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
