variable "project_name" {
  description = "name prefix for budget"
  type        = string
}

variable "monthly_budget_limit_usd" {
  description = "monthly cost cap in USD"
  type        = number
  default     = "5"
}

variable "billing_emails" {
  description = "emails to notify about budget threshold/forecast"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.billing_emails) > 0 || var.enable_budget == false
    error_message = "billing_emails must have at least one address when enable_budget is true."
  }
}

variable "enable_budget" {
  description = "whether to create a budget resource"
  type        = bool
  default     = true
}
