output "instance_id" {
  description = "id of the ec2 instance"
  value       = aws_instance.ghidra_server.id
}

output "public_ip" {
  description = "static public ip (elastic ip)"
  value       = aws_eip.ghidra.public_ip
}