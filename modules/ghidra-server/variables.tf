variable "project_name" {
  description = "name of the project for resource naming"
  type        = string
}

variable "ami_id" {
  description = "ami id to use for the ec2 instance"
  type        = string
}

variable "instance_type" {
  description = "ec2 instance type"
  type        = string
}

variable "subnet_id" {
  description = "subnet id where the instance will be launched"
  type        = string
}

variable "security_group_id" {
  description = "security group id to attach to the instance"
  type        = string
}

variable "ghidra_users" {
  description = "space-separated list of ghidra users to create"
  type        = string
  default     = "admin"
}
