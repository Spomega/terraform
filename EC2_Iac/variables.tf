variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "profile" {
  type    = string
  default = "spomega"
}

variable "project" {
  type    = string
  default = "ec2-web-project"
}

variable "key_name" {
  type    = string
  default = "terraform-tut-key"
}

variable "ssh_cidr_block" {
  type        = string
  description = "CIDR block allowed for SSH access (My IP). Use 0.0.0.0/0 for Anywhere for now; override with your public IP/32 for security."
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "owner_name" {
  type    = string
  default = "spomega"
}

variable "owner_email" {
  type    = string
  default = "spomegasys@gmail.com"
}
