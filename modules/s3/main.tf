resource "aws_s3_bucket" "this" {
  for_each = var.buckets
  bucket   = each.value.name
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each                = var.buckets
  bucket                  = aws_s3_bucket.this[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = var.buckets
  bucket   = aws_s3_bucket.this[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = var.buckets
  bucket   = aws_s3_bucket.this[each.key].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "this" {
  for_each = var.buckets
  bucket   = aws_s3_bucket.this[each.key].id

  cors_rule {
    allowed_methods = ["PUT", "POST", "GET"]
    allowed_origins = var.allowed_origins
    allowed_headers = ["content-type", "x-amz-content-sha256", "x-amz-date", "x-amz-security-token", "x-amz-signature"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# CloudFront resources (optional)
resource "aws_cloudfront_origin_access_control" "this" {
  for_each                          = var.buckets
  name                              = "${each.value.name}-oac"
  description                       = "OAC for ${each.value.name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  for_each        = var.buckets
  enabled         = true
  is_ipv6_enabled = true
  comment         = "CDN for ${each.value.name}"
  aliases         = each.value.cloudfront != null && each.value.cloudfront.alias != null ? [each.value.cloudfront.alias] : []

  origin {
    domain_name              = aws_s3_bucket.this[each.key].bucket_regional_domain_name
    origin_id                = aws_s3_bucket.this[each.key].id
    origin_access_control_id = aws_cloudfront_origin_access_control.this[each.key].id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.this[each.key].id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
  }

  price_class = "PriceClass_100"
  viewer_certificate {
    acm_certificate_arn = each.value.cloudfront.acm_certificate_arn
    ssl_support_method  = "sni-only"
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  for_each = var.buckets
  bucket   = aws_s3_bucket.this[each.key].id
  policy   = data.aws_iam_policy_document.s3_policy[each.key].json
}

data "aws_iam_policy_document" "s3_policy" {
  for_each = var.buckets
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this[each.key].arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    effect = "Allow"
  }
}

resource "aws_ssm_parameter" "s3_bucket_distribution_id" {
  name        = "/${var.environment}/cf/media/distribution-id"
  description = "Cloudfront distribution ID for Media Content"
  type        = "String"
  value       = aws_cloudfront_distribution.this["media"].id
}
