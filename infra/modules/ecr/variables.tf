variable "project" {
  description = "Project name used as ECR namespace prefix"
  type        = string
  default     = "cloudmart"
}

variable "kms_key_arn" {
  description = "KMS key ARN for ECR image encryption"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
