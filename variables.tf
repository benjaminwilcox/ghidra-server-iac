variable "aws_region" {
  description = "aws region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "name of the project for resource naming and tagging"
  type        = string
  default     = "ghidra-server"
}

variable "instance_type" {
  description = "ec2 instance type"
  type        = string
  default     = "t2.micro"
  validation {
    condition     = contains(["t2.micro", "t3.micro", "t3.small"], var.instance_type)
    error_message = "instance type must be t2.micro, t3.micro, or t3.small."
  }
}

variable "ghidra_users" {
  description = "space-separated list of Ghidra users to create"
  type        = string
  default     = "admin"
}

variable "allowed_ghidra_cidrs" {
  description = "list of cidr blocks allowed for ghidra client access (ports 13100-13102)"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.allowed_ghidra_cidrs) > 0
    error_message = "you must provide at least one CIDR (your VM IP)."
  }
}

# for billing
variable "enable_budget" {
  type    = bool
  default = true
}

variable "monthly_budget_limit_usd" {
  type    = number
  default = 5
}

variable "billing_emails" {
  type    = list(string)
  default = []
}
