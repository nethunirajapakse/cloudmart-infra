# =============================================================================
# CloudMart Messaging Module
# Standard SQS queue for order events.
# order-service publishes to this queue; notification-service polls it.
# =============================================================================

# --- Orders Queue ---
# Standard queue (not FIFO) is sufficient for order notifications.
# Visibility timeout matches notification-service's processing time.

resource "aws_sqs_queue" "orders" {
  name                       = "${var.project}-orders"
  message_retention_seconds  = 345600 # 4 days
  visibility_timeout_seconds = 30     # Must be >= notification-service processing time
  kms_master_key_id          = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.project}-orders"
  })
}
