output "table_name" {
  description = "Products table name (DYNAMODB_TABLE for product-service)"
  value       = aws_dynamodb_table.products.name
}

output "table_arn" {
  description = "Products table ARN (used later in the product-service IAM policy)"
  value       = aws_dynamodb_table.products.arn
}
