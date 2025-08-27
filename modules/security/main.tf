resource "aws_security_group" "ghidra_server" {
  name_prefix = "${var.project_name}-"
  description = "security group for ghidra server"
  vpc_id      = var.vpc_id

  # ghidra server ports (13100-13102)
  dynamic "ingress" {
    for_each = var.ghidra_allowed_cidrs
    content {
      from_port   = 13100
      to_port     = 13102
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "Ghidra client access from ${ingress.value}"
    }
  }

  # allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.project_name}-security-group"
    ManagedBy = "terraform"
    Purpose   = "cs6747"
  }
}