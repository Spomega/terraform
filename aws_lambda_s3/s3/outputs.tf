output "bucket_id" {
  value = aws_s3_bucket.code.id
}

output "bucket_arn" {
  value = aws_s3_bucket.code.arn
}

output "bucket_name" {
  value = aws_s3_bucket.code.bucket
}