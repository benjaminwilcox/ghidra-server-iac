resource "aws_budgets_budget" "monthly_cost" {
  count       = var.enable_budget ? 1 : 0
  name        = "${var.project_name}-monthly-budget"
  budget_type = "COST"
  time_unit   = "MONTHLY"

  limit_amount = var.monthly_budget_limit_usd
  limit_unit   = "USD"

  cost_types {
    include_credit             = false
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = false
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_amortized              = false
    use_blended                = false
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "FORECASTED"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = var.billing_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = var.billing_emails
  }
}
