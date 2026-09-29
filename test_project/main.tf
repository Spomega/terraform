# Test project
# 1. Create vpc
# 2. Create Internet Gateway
# 3. Create Custom Route Table
# 4. Create a Subnet
# 5. Associate subnet with Route Table
# 6. Create Security Group to allow port 22,80,443
# 7. Create a network interface with an ip in the subnet that was created in step 4
# 8. Assign an elastic IP to the network interface created in step 7
# 9. Create Ubuntu server and install/enable apache2


provider "aws" {
  region  = var.region
  profile = var.profile
}

data "aws_availability_zones" "this" {
  state = "available"
}

# 1. Create vpc
resource "aws_vpc" "spo-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "spotest-vpc"
  }
}

# 2. Create Internet Gateway
resource "aws_internet_gateway" "spo-igw" {
  vpc_id = aws_vpc.spo-vpc.id
  tags = {
    Name = "spotest-igw"
  }
}

# 3. Create Custom Route Table
resource "aws_route_table" "spo-rt" {
  vpc_id = aws_vpc.spo-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.spo-igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.spo-igw.id
  }

  tags = {
    Name = "spotest-rt"
  }
}

# 4. Create a Subnet
resource "aws_subnet" "spo-subnet" {
  vpc_id            = aws_vpc.spo-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.this.names[0]
  tags = {
    Name = "spotest-subnet"
  }
}

# 5. Associate subnet with Route Table
resource "aws_route_table_association" "spo-rt-assoc" {
  subnet_id      = aws_subnet.spo-subnet.id
  route_table_id = aws_route_table.spo-rt.id
}

# 6. Create Security Group to allow port 22,80,443
resource "aws_security_group" "allow-web" {
  vpc_id      = aws_vpc.spo-vpc.id
  name        = "spotest-allow-web"
  description = "Allow port 22,80,443"

  ingress {
    description = "Allow port 443 for HTTPS Traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow port 80 for HTTP Traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow port 22 for SSH Traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "spotest-allow-web"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "spo-nic" {
  subnet_id       = aws_subnet.spo-subnet.id
  private_ips     = ["10.0.1.10"]
  security_groups = [aws_security_group.allow-web.id]
  tags = {
    Name = "spotest-nic"
  }
}

# 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "spo-eip" {
  network_interface         = aws_network_interface.spo-nic.id
  associate_with_private_ip = "10.0.1.10"
  depends_on                = [aws_internet_gateway.spo-igw]
  tags = {
    Name = "spotest-eip"
  }
}

# 9. Create Ubuntu server and install/enable apache2
resource "aws_instance" "spo-server" {
  ami               = "ami-05852c5f195d545ea"
  instance_type     = "t3.micro"
  availability_zone = data.aws_availability_zones.this.names[0]
  key_name          = var.key_name

  network_interface {
    network_interface_id = aws_network_interface.spo-nic.id
    device_index         = 0
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update
    sudo apt install -y apache2
    systemctl enable apache2
    systemctl start apache2
    echo "<h1>Hello World!</h1>" | sudo tee /var/www/html/index.html
  EOF

  tags = {
    Name = "spotest-server"
  }
}




