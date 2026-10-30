output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "dynamodb_table_names" {
  value = { for env, m in module.dynamodb : env => m.table_name }
}

output "orders_queue_urls" {
  value = { for env, m in module.messaging : env => m.queue_url }
}
