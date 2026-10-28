variable "project" {
  description = "Project name"
  type        = string
  default     = "cloudmart"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "custom_domain_name" {
  description = "Public DNS name for the frontend, for example cloudmart.example.com. Leave empty to use the ALB DNS name with a self-signed fallback certificate."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID used to DNS-validate the public ACM certificate. Required for trusted HTTPS when custom_domain_name is set and acm_certificate_arn is empty."
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "Existing issued ACM certificate ARN to use for the ALB HTTPS listener. Takes precedence over creating a DNS-validated certificate."
  type        = string
  default     = ""
}

variable "enable_guardduty" {
  description = "Whether to enable GuardDuty. Some AWS Free Plan accounts require a paid plan or service subscription before GuardDuty can be enabled."
  type        = bool
  default     = true
}
