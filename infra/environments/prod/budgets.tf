# =============================================================================
# CloudMart Cost Management — AWS Budgets
# Assignment Section 3.8: Cost Management [M]
#
# Creates a monthly budget alert that notifies via email when:
#   - Actual spend exceeds 80% of the budget threshold (early warning)
#   - Actual spend exceeds 100% of the budget threshold (action required)
#   - Forecasted spend exceeds 100% of the budget threshold (predictive alert)
#
# Budget is set to $50/month which covers:
#   - 2x EKS worker nodes (t3.medium): ~$60.74/month
#   - RDS PostgreSQL (db.t3.micro):    ~$15.00/month
#   - NAT Gateway:                     ~$6.00/month
#   - DynamoDB (on-demand):            ~$0.30/month
#   - SQS, KMS, CloudWatch, misc:      ~$5.00/month
# =============================================================================

resource "aws_budgets_budget" "monthly" {
  name         = "${var.project}-monthly-budget"
  budget_type  = "COST"
  limit_amount = "50"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # --- Alert #1: 80% of budget (early warning) ---
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.owner_email]
  }

  # --- Alert #2: 100% of budget (over budget — action required) ---
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.owner_email]
  }

  # --- Alert #3: Forecasted to exceed 100% (predictive alert) ---
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.owner_email]
  }
}
