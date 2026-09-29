module "code_bucket" {
  source  = "./s3"
  project = var.project
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/code"
  output_path = "${path.module}/function.zip"
}

resource "aws_s3_object" "function_zip" {
  bucket = module.code_bucket.bucket_id
  key    = "packages/function.zip"
  source = data.archive_file.lambda_zip.output_path
  etag   = filemd5(data.archive_file.lambda_zip.output_path)
}

# Build a Lambda layer with third-party dependencies using pip
resource "null_resource" "build_layer" {
  triggers = {
    requirements_hash = filesha256("${path.module}/layer/requirements.txt")
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command     = <<EOT
set -euo pipefail
rm -rf "${path.module}/.layer_build"
mkdir -p "${path.module}/.layer_build/python"
python3 -m pip install -r "${path.module}/layer/requirements.txt" -t "${path.module}/.layer_build/python"
EOT
  }
}

data "archive_file" "layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/.layer_build"
  output_path = "${path.module}/layer.zip"
  depends_on  = [null_resource.build_layer]
}

resource "aws_s3_object" "layer_zip" {
  bucket = module.code_bucket.bucket_id
  key    = "packages/layer.zip"
  source = data.archive_file.layer_zip.output_path
}

resource "aws_lambda_layer_version" "deps" {
  layer_name          = "${var.project}-deps"
  compatible_runtimes = ["python3.10"]
  s3_bucket           = module.code_bucket.bucket_id
  s3_key              = aws_s3_object.layer_zip.key
  source_code_hash    = data.archive_file.layer_zip.output_base64sha256
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.project}-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "fn" {
  function_name    = "${var.project}-function"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "app.handler"
  runtime          = "python3.10"
  s3_bucket        = module.code_bucket.bucket_id
  s3_key           = aws_s3_object.function_zip.key
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  layers           = [aws_lambda_layer_version.deps.arn]
  depends_on       = [aws_iam_role_policy_attachment.basic]
}

resource "aws_lambda_function_url" "url" {
  function_name      = aws_lambda_function.fn.arn
  authorization_type = "AWS_IAM"
}

resource "aws_lambda_permission" "invoke_url_iam" {
  statement_id             = "AllowIamFunctionUrlInvoke"
  action                   = "lambda:InvokeFunctionUrl"
  function_name            = aws_lambda_function.fn.function_name
  principal                = "arn:aws:iam::509157248746:terraform-ci"
  function_url_auth_type   = "AWS_IAM"
  depends_on               = [aws_lambda_function_url.url]
}

# Manage log retention for the Lambda log group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.fn.function_name}"
  retention_in_days = 14
}