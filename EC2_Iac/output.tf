output "web_server_public_ip" {
  description = "Public IPv4 address of the EC2 web server"
  value       = aws_instance.web_server.public_ip
}

output "web_server_public_dns" {
  description = "Public IPv4 DNS of the EC2 web server"
  value       = aws_instance.web_server.public_dns
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web_server.id
}

output "ssh_command" {
  description = "Command to SSH into the instance (use correct user for AMI: ec2-user for Amazon Linux)"
  value       = "ssh -i /path/to/${var.key_name}.pem ec2-user@${aws_instance.web_server.public_ip}"
}
