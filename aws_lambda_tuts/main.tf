provider "aws" {
  region = "eu-central-1"
  profile = "terraform"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "terraform_lambda_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# IAM policy for logging from lambda

resource "aws_iam_policy" "iam_policy_for_lambda" {
  name = "terraform_lambda_logging_policy"
  path = "/"
  description = "IAM policy for managing aws lambda role"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:eu-central-1:509157248746:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

# Policy Attachment on the lambda  role
resource "aws_iam_role_policy_attachment" "lambda_exec_role_policy_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn
}

# Generate an archive from content, file, or directory of files
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/python"
  output_path = "${path.module}/python/lambda_function.zip"
}

# Create a lambda function
# In terraform ${path.module} we are referencing the current module directory
resource "aws_lambda_function" "lambda_function" {
  function_name    = "terraform_lambda_function"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "hello.lambda_handler"
  runtime          = "python3.10"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  depends_on       = [aws_iam_role_policy_attachment.lambda_exec_role_policy_attachment]
}

output "teraform_aws_role_output" {
  value = aws_iam_role.lambda_exec_role.name
}

output "teraform_aws_role_arn_output" {
  value = aws_iam_role.lambda_exec_role.arn
}

output "teraform_logging_arn_output" {
  value = aws_iam_policy.iam_policy_for_lambda.arn
}
