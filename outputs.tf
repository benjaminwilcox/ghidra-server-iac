output "ghidra_server_ip" {
  description = "public ip address of the ghidra server (elastic ip)"
  value       = module.ghidra_server.public_ip
}

output "ssm_shell" {
  description = "start an ssm shell on the instance"
  value       = "aws ssm start-session --target ${module.ghidra_server.instance_id}"
}

output "ghidra_client_instructions" {
  description = "instructions for connecting with ghidra client"
  value = [
    "1. Open Ghidra on your VM",
    "2. Go to File → New Project → Shared Project...",
    "3. Server Name: ${module.ghidra_server.public_ip}",
    "4. Port Number: 13100",
    "5. User ID: <username>",
    "6. Password: changeme (you'll be asked to change it)"
  ]
}