output "kms_key_arn" {
  description = "KMS key ARN — pass to database, messaging, and ECR modules"
  value       = aws_kms_key.main.arn
}

output "kms_key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.main.key_id
}

output "jwt_secret_arn" {
  description = "Secrets Manager ARN for JWT secret — used in IRSA policy for user-service"
  value       = aws_secretsmanager_secret.jwt.arn
}

output "jwt_secret_name" {
  description = "Secrets Manager secret name for JWT secret"
  value       = aws_secretsmanager_secret.jwt.name
}

output "waf_acl_arn" {
  description = "WAFv2 Web ACL ARN"
  value       = aws_wafv2_web_acl.alb.arn
}

output "alb_certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS listener"
  value       = local.alb_certificate_arn
}
