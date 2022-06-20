
## CloudWatch metric stream
resource "aws_cloudwatch_metric_stream" "dynatrace" {
  name          = "dynatrace"
  firehose_arn  = aws_kinesis_firehose_delivery_stream.dynatrace.arn
  output_format = "opentelemetry0.7"
  role_arn      = aws_iam_role.dynatrace_metric_stream.arn
  include_filter{
    namespace = var.PINamespace
  }
  dynamic "include_filter" {
    for_each = var.DynatraceMetricStreamNamespaceList
    iterator = item

    content {
      namespace = item.value
    }
  }
}


## Kinesis Firehose
resource "aws_kinesis_firehose_delivery_stream" "dynatrace" {
  name        = "dynatrace"
  destination = "http_endpoint"

  http_endpoint_configuration {
    name               = "dynatrace"
    access_key         = var.DynatraceApiKey
    buffering_interval = 60 # seconds
    buffering_size     = 3  # MB
    retry_duration     = 900 # seconds
    role_arn           = aws_iam_role.dynatrace_firehose.arn
    s3_backup_mode     = "FailedDataOnly"
    url                = var.FirehoseHttpDeliveryEndpoint

    cloudwatch_logging_options {
      enabled = false
    }

    processing_configuration {
      enabled = false
    }

    request_configuration {
      content_encoding = "GZIP"    

      common_attributes {
          name = "dt-url"
          value = var.DynatraceEnvironmentUrl
      }

      common_attributes {
          name = "require-valid-certificate"
          value = var.RequireValidCertificate
      }
    }

  }

  s3_configuration {
    bucket_arn      = aws_s3_bucket.dynatrace_firehose_backup.arn
    buffer_interval = 300 # seconds
    buffer_size     = 5   # MB
    prefix          = "metrics/"
    role_arn        = aws_iam_role.dynatrace_firehose.arn

    cloudwatch_logging_options {
      enabled = false
    }
  }

  server_side_encryption {
    enabled = false
  }
}

resource "aws_iam_role" "dynatrace_firehose" {
  name               = "dynatrace-firehose"
  assume_role_policy = data.aws_iam_policy_document.dynatrace_firehose_assume.json
}

data "aws_iam_policy_document" "dynatrace_firehose_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["firehose.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role_policy" "dynatrace_firehose_s3_backup" {
  name   = "s3-backup"
  policy = data.aws_iam_policy_document.dynatrace_firehose_s3_backup.json
  role   = aws_iam_role.dynatrace_firehose.id
}

data "aws_iam_policy_document" "dynatrace_firehose_s3_backup" {
  statement {
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
    ]

    resources = [aws_s3_bucket.dynatrace_firehose_backup.arn]
  }

  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = ["${aws_s3_bucket.dynatrace_firehose_backup.arn}"]
  }
}

## Kinesis Firehose - S3 error/backup bucket
resource "aws_s3_bucket" "dynatrace_firehose_backup" {
  bucket = "firehose-backup-${var.AWSAccountID}"
}

#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "sse_backup" {
  bucket = aws_s3_bucket.dynatrace_firehose_backup.bucket  
  rule {    
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "versioning_backup" {
  bucket = aws_s3_bucket.dynatrace_firehose_backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "block_public_access_backup" {
  bucket = aws_s3_bucket.dynatrace_firehose_backup.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "apm_log_bucket" {
  bucket = "firehose-log-${var.AWSAccountID}"
}

#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "sse_log" {
  bucket = aws_s3_bucket.apm_log_bucket.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "versioning_log" {
  bucket = aws_s3_bucket.apm_log_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "block_public_access_log" {
  bucket = aws_s3_bucket.apm_log_bucket.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_acl" "log_bucket_acl" {
  bucket = aws_s3_bucket.apm_log_bucket.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_logging" "apm_log_link" {
  bucket = aws_s3_bucket.dynatrace_firehose_backup.id
  target_bucket = aws_s3_bucket.apm_log_bucket.id
  target_prefix = "log/"
}

resource "aws_iam_role" "dynatrace_metric_stream" {
  # note: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-metric-streams-trustpolicy.html
  name               = "dynatrace-metric-stream"
  assume_role_policy = data.aws_iam_policy_document.dynatrace_metric_stream_assume.json
}

data "aws_iam_policy_document" "dynatrace_metric_stream_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["streams.metrics.cloudwatch.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role_policy" "dynatrace_metric_stream_firehose" {
  name   = "firehose"
  policy = data.aws_iam_policy_document.dynatrace_metric_stream_firehose.json
  role   = aws_iam_role.dynatrace_metric_stream.id
}

data "aws_iam_policy_document" "dynatrace_metric_stream_firehose" {
  statement {
    actions = [
      "firehose:PutRecord",
      "firehose:PutRecordBatch",
    ]

    resources = [aws_kinesis_firehose_delivery_stream.dynatrace.arn]
  }
}