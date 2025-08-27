# iam role for ec2 instance (basic permissions)
resource "aws_iam_role" "ghidra_server" {
  name_prefix = "${var.project_name}-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-role"
    ManagedBy = "terraform"
    Purpose   = "cs6747"
  }
}

resource "aws_iam_instance_profile" "ghidra_server" {
  name_prefix = "${var.project_name}-profile-"
  role        = aws_iam_role.ghidra_server.name

  tags = {
    Name = "${var.project_name}-instance-profile"
    ManagedBy = "terraform"
    Purpose   = "cs6747"
  }
}

# ssm
resource "aws_iam_role_policy_attachment" "ssm_core_attach" {
  role       = aws_iam_role.ghidra_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ec2 Instance
resource "aws_instance" "ghidra_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [var.security_group_id]
  subnet_id             = var.subnet_id
  iam_instance_profile  = aws_iam_instance_profile.ghidra_server.name
  
  user_data = templatefile("${path.module}/user_data.sh", {
    ghidra_users = var.ghidra_users
    project_name = var.project_name
  })
  
  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-server"
    ManagedBy = "terraform"
    Purpose   = "cs6747"
  }

  lifecycle {
    create_before_destroy = true
  }
}