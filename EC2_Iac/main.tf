resource "aws_security_group" "web_sg" {
  name        = "${var.project}-sg"
  description = "Allow SSH (My IP) and HTTP (Anywhere) for ${var.project}"

  ingress {
    description = "SSH from My IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr_block]
  }

  ingress {
    description = "HTTP from Anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-sg"
  }
}

resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data              = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y httpd
    sudo systemctl start httpd
    sudo systemctl enable httpd
    echo "<html><h1>My First EC2 Project</h1><p>Created by: ${var.owner_name}.</p><p>Email: ${var.owner_email}</p></html>" | sudo tee /var/www/html/index.html
  EOF

  tags = {
    Name = "${var.project}-server"
  }
}
