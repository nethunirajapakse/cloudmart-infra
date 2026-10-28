output "state_bucket_name" {
  description = "Paste this value into environments/prod/backend.tf and environments/staging/backend.tf"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "lock_table_name" {
  description = "Paste this value into environments/prod/backend.tf and environments/staging/backend.tf"
  value       = aws_dynamodb_table.terraform_locks.name
}
