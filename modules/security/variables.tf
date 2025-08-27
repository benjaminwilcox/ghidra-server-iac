variable "project_name" {
  description = "name of the project for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "vpc id where security groups will be created"
  type        = string
}

variable "ghidra_allowed_cidrs" {
  description = "list of CIDR blocks allowed ghidra client access"
  type        = list(string)

  validation {
    condition     = length(var.ghidra_allowed_cidrs) > 0
    error_message = "provide at least one CIDR for client access to ghidra."
  }
}