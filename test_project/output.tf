output "web_server_public_ip" {
  value = aws_eip.spo-eip.public_ip
}

output "availability_zone" {
  value = aws_subnet.spo-subnet.availability_zone
}
