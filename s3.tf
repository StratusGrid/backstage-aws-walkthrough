resource "random_string" "random" {
  length           = 6
  special          = false
}

resource "aws_s3_bucket" "template_bucket" {
  bucket = "${local.name}-templates-${lower(random_string.random.result)}"
}

resource "aws_s3_bucket_versioning" "template_bucket_versioning" {
  bucket = aws_s3_bucket.template_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "template_bucket_sse" {
  bucket = aws_s3_bucket.template_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_logging" "template_bucket_logging" {
  bucket = aws_s3_bucket.template_bucket.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "log/"
}

resource "aws_s3_bucket_public_access_block" "template_bucket_block" {
  bucket                  = aws_s3_bucket.template_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = "${local.name}-templates-logs-${lower(random_string.random.result)}"
}

resource "aws_s3_bucket_versioning" "log_bucket_versioning" {
  bucket = aws_s3_bucket.log_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket_sse" {
  bucket = aws_s3_bucket.log_bucket.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "log_bucket_block" {
  bucket                  = aws_s3_bucket.log_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.template_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.backstage_task.arn]
    }
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["${aws_s3_bucket.template_bucket.arn}"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.backstage_task.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_access_from_backstage" {
  bucket = aws_s3_bucket.template_bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}
