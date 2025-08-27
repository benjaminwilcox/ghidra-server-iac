output "ghidra_server_sg_id" {
  description = "id of the ghidra server security group"
  value       = aws_security_group.ghidra_server.id
}