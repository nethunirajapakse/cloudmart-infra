output "orders_queue_url" {
  description = "SQS orders queue URL - set as SQS_QUEUE_URL env var in order-service and notification-service"
  value       = aws_sqs_queue.orders.url
}

output "orders_queue_arn" {
  description = "SQS orders queue ARN - used in IRSA policies for order-service and notification-service"
  value       = aws_sqs_queue.orders.arn
}
