# Product catalogue for product-service. The service keys products by "id".
resource "aws_dynamodb_table" "products" {
  name         = "${var.project}-${var.environment}-products"
  billing_mode = "PAY_PER_REQUEST" # no idle cost; pay only per request
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Environment = var.environment
  }
}
