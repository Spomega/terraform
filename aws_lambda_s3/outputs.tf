output "bucket_name" {
  value = module.code_bucket.bucket_name
}

output "function_name" {
  value = aws_lambda_function.fn.function_name
}

output "function_url" {
  value = aws_lambda_function_url.url.function_url
}