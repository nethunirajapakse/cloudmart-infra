output "account_id" {
  description = "AWS account this environment is deployed into"
  value       = data.aws_caller_identity.current.account_id
}
