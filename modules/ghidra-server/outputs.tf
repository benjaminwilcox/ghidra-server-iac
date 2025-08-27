output "instance_id" {
  description = "id of the ec2 instance"
  value       = aws_instance.ghidra_server.id
}

output "public_ip" {
  description = "public ip address of the ec2 instance"
  value       = aws_instance.ghidra_server.public_ip
}

output "public_dns" {
  description = "public dns name of the ec2 instance"
  value       = aws_instance.ghidra_server.public_dns
}