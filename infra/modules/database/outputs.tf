output "db_endpoint" {
  description = "RDS PostgreSQL hostname — passed to Secrets Manager and K8s ConfigMap"
  value       = aws_db_instance.postgres.address
}

output "db_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.postgres.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.postgres.db_name
}

output "db_password" {
  description = "RDS master password — stored in Secrets Manager, never use directly"
  value       = random_password.db.result
  sensitive   = true
}

output "db_secret_arn" {
  description = "Secrets Manager ARN for DB credentials — used in IRSA policy for user-service"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_secret_name" {
  description = "Secrets Manager secret name for DB credentials"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "dynamodb_table_name" {
  description = "DynamoDB products table name — used in product-service env var"
  value       = aws_dynamodb_table.products.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB products table ARN — used in IRSA policy for product-service"
  value       = aws_dynamodb_table.products.arn
}
