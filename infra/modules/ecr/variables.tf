variable "project" {
  description = "Project name, used as the repository namespace (project/service)"
  type        = string
  default     = "cloudmart"
}

variable "services" {
  description = "Service names; one ECR repository is created for each"
  type        = list(string)
}
