# Private, encrypted buckets. Not modules/s3: that module always creates a
# CloudFront distribution and a public-read policy for the media CDN, which
# private documents must never sit behind.
#
# Key layout (contract for MDI-216 ingestion):
#   quarantine bucket  pending/<owner>/<random>   presigned uploads, not yet accepted
#                      raw/...                    accepted, pinned object versions
#                      derivatives/...            OCR page derivatives
#   artifacts bucket   results/...                job results (unaccepted results age out)
#                      metadata/...               content-free metadata
# Lifecycle matches the DynamoDB TTL retention. There is no account-deletion
# cleanup path; data ages out.

locals {
  buckets = {
    quarantine = {
      name = "${local.prefix}-quarantine-${local.suffix}"
      rules = {
        pending     = var.pending_upload_expiry_days
        raw         = var.raw_expiry_days
        derivatives = var.raw_expiry_days
      }
    }
    artifacts = {
      name = "${local.prefix}-artifacts-${local.suffix}"
      rules = {
        results  = var.raw_expiry_days
        metadata = var.metadata_expiry_days
      }
    }
  }
}

resource "aws_s3_bucket" "this" {
  for_each = local.buckets

  bucket        = each.value.name
  force_destroy = false
  tags          = local.tags
}

resource "aws_s3_bucket_ownership_controls" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = local.buckets

  bucket                  = aws_s3_bucket.this[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id
  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
  }
}

# No CORS: browsers never talk to these buckets. Uploads go through the
# service API and its presigned URLs are added deliberately in MDI-216.

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = local.buckets

  bucket     = aws_s3_bucket.this[each.key].id
  depends_on = [aws_s3_bucket_versioning.this]

  dynamic "rule" {
    for_each = each.value.rules
    content {
      id     = "expire-${rule.key}"
      status = "Enabled"
      filter {
        prefix = "${rule.key}/"
      }
      expiration {
        days = rule.value
      }
      noncurrent_version_expiration {
        noncurrent_days = 1
      }
    }
  }

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "remove-expired-delete-markers"
    status = "Enabled"
    filter {}
    expiration {
      expired_object_delete_marker = true
    }
  }
}

data "aws_iam_policy_document" "bucket" {
  for_each = local.buckets

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.this[each.key].arn, "${aws_s3_bucket.this[each.key].arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  dynamic "statement" {
    for_each = var.deletion_protection ? [1] : []
    content {
      sid       = "DenyBucketDeletion"
      effect    = "Deny"
      actions   = ["s3:DeleteBucket"]
      resources = [aws_s3_bucket.this[each.key].arn]
      principals {
        type        = "*"
        identifiers = ["*"]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  for_each = local.buckets

  bucket     = aws_s3_bucket.this[each.key].id
  policy     = data.aws_iam_policy_document.bucket[each.key].json
  depends_on = [aws_s3_bucket_public_access_block.this]
}
