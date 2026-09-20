# Regional ACM (default AWS provider). modules/ssl is hardcoded to us-east-1
# for CloudFront and is left unchanged.

resource "aws_acm_certificate" "this" {
  for_each = { for d in var.root_domains : d.domain => d }

  domain_name               = each.value.domain
  validation_method         = "DNS"
  subject_alternative_names = each.value.subdomains

  tags = {
    Name = "${each.value.domain} SSL Certificate ${var.region}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in flatten([
      for cert in aws_acm_certificate.this : [
        for option in cert.domain_validation_options : {
          domain_name           = option.domain_name
          resource_record_name  = option.resource_record_name
          resource_record_type  = option.resource_record_type
          resource_record_value = option.resource_record_value
        }
      ]
    ]) : dvo.domain_name => dvo
  }

  zone_id = var.hosted_zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 60

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  for_each = aws_acm_certificate.this

  certificate_arn         = each.value.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

locals {
  parameters = {
    for cert in aws_acm_certificate.this : "certificate_${cert.domain_name}_${var.region}" => {
      value       = cert.arn
      type        = "SecureString"
      prefix      = "ssl/arn"
      description = "ACM ARN for ${cert.domain_name} in ${var.region}"
      tags        = {}
    }
  }
}

module "ssm" {
  source      = "../ssm"
  environment = var.environment
  region      = var.region
  parameters  = local.parameters
}
