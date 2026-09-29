resource "random_id" "suffix" {
  byte_length = 3
}

resource "aws_s3_bucket" "code" {
  bucket        = "${var.project}-code-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "v" {
  bucket = aws_s3_bucket.code.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lc" {
  bucket = aws_s3_bucket.code.id

  rule {
    id     = "expire-packages"
    status = "Enabled"
    filter {
      prefix = "packages/"
    }
    expiration {
      days = 30
    }
    noncurrent_version_expiration {
      noncurrent_days = 7
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}