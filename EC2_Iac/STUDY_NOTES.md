# Terraform EC2 Web Server Study Notes

## 1. What We Built

This project uses Terraform to create an Amazon EC2 web server in AWS.

The server:

- Uses the Amazon Linux 2 AMI.
- Runs as a `t3.micro` instance.
- Uses an existing EC2 key pair for SSH access.
- Allows SSH on port 22.
- Allows HTTP on port 80.
- Installs and starts Apache automatically.
- Publishes a simple HTML page.
- Exposes the server IP and DNS name as Terraform outputs.

The project is managed from:

```text
/Users/spomega/Documents/code/active_code/spotest/Terraform/EC2_Iac
```

## 2. Terraform Fundamentals

Terraform is an Infrastructure as Code tool. Instead of creating AWS resources manually in the console, we describe the desired infrastructure in configuration files.

Terraform then:

1. Reads the configuration.
2. Compares it with the current state.
3. Creates, updates, or removes resources to match the configuration.

Important Terraform concepts:

- **Provider**: Plugin that lets Terraform communicate with AWS.
- **Resource**: Something Terraform creates or manages, such as an EC2 instance.
- **Data source**: Information Terraform reads from AWS, such as the latest AMI.
- **Variable**: An input that makes configuration reusable.
- **Output**: A value Terraform displays after deployment.
- **State**: Terraform's record of the infrastructure it manages.
- **Plan**: A preview of changes before they are applied.

## 3. Project Files

| File | Purpose |
|---|---|
| `providers.tf` | AWS provider configuration and AMI lookup |
| `variables.tf` | Input variables and default values |
| `terraform.tfvars` | Project-specific variable values |
| `main.tf` | Security group and EC2 instance resources |
| `output.tf` | Public IP, DNS, instance ID, and SSH command |

Terraform automatically loads `terraform.tfvars` when it is in the same directory as the other `.tf` files.

## 4. AWS Authentication and Region

The provider is configured in `providers.tf`:

```hcl
provider "aws" {
  region  = var.region
  profile = var.profile
}
```

The project uses:

- AWS region: `eu-central-1`
- AWS CLI profile: `spomega`

The profile must exist locally. Verify it before using Terraform:

```bash
aws sts get-caller-identity --profile spomega
```

You can also set the profile for the current shell:

```bash
export AWS_PROFILE=spomega
```

Do not add spaces around the equals sign in shell assignments.

## 5. Variables

Variables are declared in `variables.tf`:

```hcl
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
```

The values used for this deployment are in `terraform.tfvars`:

```hcl
ssh_cidr_block = "0.0.0.0/0"
key_name       = "terraform-tut-key"
owner_name     = "spomega"
owner_email    = "spomegasys@gmail.com"
```

Terraform uses this precedence model:

1. Explicit command-line `-var` values.
2. A specified `-var-file`.
3. Automatically loaded `terraform.tfvars`.
4. Defaults declared in `variables.tf`.

The `ssh_cidr_block` value is currently `0.0.0.0/0`, which allows SSH from anywhere. This is useful for temporary testing but is not recommended for production. A safer value is your public IP with `/32`, for example:

```hcl
ssh_cidr_block = "79.229.92.219/32"
```

## 6. Finding the AMI

Rather than hardcoding an AMI ID, the project queries AWS:

```hcl
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
```

This data source asks AWS for the newest Amazon-owned Amazon Linux 2 AMI matching the filter.

The EC2 resource then uses the result:

```hcl
ami = data.aws_ami.amazon_linux_2.id
```

AMI IDs are region-specific, so dynamically finding an AMI avoids copying an ID from the wrong region.

## 7. Security Group: Ingress and Egress

The security group acts as a virtual firewall.

### Ingress

Ingress means inbound traffic entering the instance:

```hcl
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = [var.ssh_cidr_block]
}
```

This rule allows SSH on port 22.

The HTTP rule allows web traffic:

```hcl
ingress {
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

HTTP is open to everyone because visitors need to reach the website.

### Egress

Egress means outbound traffic leaving the instance:

```hcl
egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
```

This allows the instance to access the internet for package installation and updates.

Security groups are stateful. If an allowed connection receives a response, the response traffic is automatically allowed.

## 8. Launching the EC2 Instance

The instance resource combines the AMI, size, key pair, and security group:

```hcl
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
}
```

Terraform understands this dependency:

```text
EC2 instance -> security group -> AWS VPC
```

The `key_name` must refer to an existing EC2 key pair in the selected AWS region. The matching private `.pem` file is required for normal SSH access.

## 9. Bootstrapping Apache with User Data

`user_data` is a script that EC2 runs during the first boot:

```hcl
user_data = <<-EOF
  #!/bin/bash
  sudo yum update -y
  sudo yum install -y httpd
  sudo systemctl start httpd
  sudo systemctl enable httpd
  echo "<html><h1>My First EC2 Project</h1>...</html>" | sudo tee /var/www/html/index.html
EOF
```

The script:

1. Updates installed packages.
2. Installs Apache, whose service name is `httpd` on Amazon Linux.
3. Starts Apache immediately.
4. Enables Apache to start after future reboots.
5. Writes the web page to Apache's default document root:
   `/var/www/html/index.html`.

User data runs asynchronously. The instance may be marked running before the script has completed, so wait briefly before testing the site.

## 10. Formatting and Validation

Run these commands from the project directory:

```bash
terraform fmt -recursive
terraform init
terraform validate
```

What they do:

- `terraform fmt`: Applies Terraform's standard formatting.
- `terraform init`: Downloads providers and initializes the working directory.
- `terraform validate`: Checks Terraform syntax and configuration structure.

## 11. Planning and Applying

A plan previews changes:

```bash
terraform plan
```

To save the plan to a file:

```bash
terraform plan -out=tfplan
```

The `-out` option requires a filename. This is incorrect:

```bash
terraform plan -out
```

Apply the exact saved plan:

```bash
terraform apply tfplan
```

Using a saved plan is useful because it separates review from execution.

## 12. Reading Outputs

The project defines outputs in `output.tf`:

```hcl
output "web_server_public_ip" {
  value = aws_instance.web_server.public_ip
}
```

Display all outputs:

```bash
terraform output
```

Display one value without quotes:

```bash
terraform output -raw web_server_public_ip
```

Open the website over HTTP:

```bash
IP=$(terraform output -raw web_server_public_ip)
open "http://$IP/index.html"
```

This project configures HTTP, not HTTPS. Use `http://`, not `https://`. HTTPS would require a certificate, port 443, and Apache TLS configuration.

## 13. Connecting with SSH

Amazon Linux uses the `ec2-user` account:

```bash
chmod 400 /path/to/terraform-tut-key.pem
IP=$(terraform output -raw web_server_public_ip)
ssh -i /path/to/terraform-tut-key.pem ec2-user@"$IP"
```

If the connection fails, check:

1. The instance has a public IP.
2. The security group permits port 22 from your current IP.
3. The key pair name matches the `.pem` file.
4. The username is `ec2-user`.
5. The instance is in a subnet with internet routing.

Inside the instance:

```bash
sudo systemctl status httpd
curl http://localhost/index.html
cat /var/www/html/index.html
```

## 14. Troubleshooting the Web Page

If the file exists but the browser cannot reach it:

```bash
sudo systemctl status httpd
curl http://localhost
```

From your local machine:

```bash
IP=$(terraform output -raw web_server_public_ip)
curl -I "http://$IP"
```

Common causes:

- Using `https://` when only HTTP is configured.
- Apache has not finished installing.
- Port 80 is missing from the security group.
- The public IP changed after stopping and starting the instance.
- The instance does not have a route to the internet.

## 15. State and Cleanup

Terraform stores resource tracking information in `terraform.tfstate`. Do not edit it manually or commit it to a public repository.

When the project is finished, remove the resources:

```bash
terraform destroy
```

Review the destroy plan and confirm it before proceeding.

## 16. Teaching Checklist

Ask learners to explain:

1. Why Terraform needs a provider.
2. The difference between a resource and a data source.
3. Why the AMI is looked up dynamically.
4. What ingress port 22 is used for.
5. What ingress port 80 is used for.
6. Why `0.0.0.0/0` is risky for SSH.
7. What `user_data` does.
8. Why `ec2-user` is used for Amazon Linux.
9. Why the browser URL uses HTTP instead of HTTPS.
10. Why `terraform plan` should be reviewed before `terraform apply`.

## 17. Recommended Improvements

For a production-quality version:

- Restrict SSH to a trusted `/32` CIDR.
- Store Terraform state in an encrypted remote S3 backend with locking.
- Do not commit `terraform.tfvars` if it contains private values.
- Use HTTPS with AWS Certificate Manager and an Application Load Balancer.
- Use a dedicated IAM role instead of relying on a local profile for workloads.
- Pin provider versions.
- Add monitoring and centralized logging.
- Use a launch template or module for reusable EC2 deployments.
