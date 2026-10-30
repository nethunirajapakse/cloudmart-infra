variable "project" {
  type    = string
  default = "cloudmart"
}

variable "environment" {
  description = "Environment name (prod or staging)"
  type        = string
}
