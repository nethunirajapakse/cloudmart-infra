# Dead-letter queue: messages that fail processing repeatedly land here
# instead of being retried forever.
resource "aws_sqs_queue" "orders_dlq" {
  name                      = "${var.project}-${var.environment}-orders-dlq"
  message_retention_seconds = 1209600 # 14 days, to leave time to investigate
  sqs_managed_sse_enabled   = true

  tags = {
    Environment = var.environment
  }
}

resource "aws_sqs_queue" "orders" {
  name                       = "${var.project}-${var.environment}-orders"
  visibility_timeout_seconds = 60 # must exceed the consumer's processing time
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20 # long polling: fewer empty responses
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = 5
  })

  tags = {
    Environment = var.environment
  }
}
