output "queue_url" {
  description = "Orders queue URL (SQS_QUEUE_URL for order-service and notification-service)"
  value       = aws_sqs_queue.orders.url
}

output "queue_arn" {
  description = "Orders queue ARN (used later in IAM policies)"
  value       = aws_sqs_queue.orders.arn
}

output "dlq_arn" {
  description = "Dead-letter queue ARN"
  value       = aws_sqs_queue.orders_dlq.arn
}
