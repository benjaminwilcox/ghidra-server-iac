output "account_id" {
  description = "aws account id"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "current aws region"
  value       = data.aws_region.current.name
}

output "vpc_id" {
  description = "default vpc id"
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "default subnet ids"
  value       = data.aws_subnets.default.ids
}

output "ubuntu_ami_id" {
  description = "latest Ubuntu 22.04 LTS ami id"
  value       = data.aws_ami.ubuntu.id
}
