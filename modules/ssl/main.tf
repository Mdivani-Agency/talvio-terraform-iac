provider "aws" {
  alias  = "acm"
  region = "us-east-1"
}

resource "aws_acm_certificate" "this" {
  for_each = { for d in var.root_domains : d.domain => d }

  provider          = aws.acm
  domain_name       = each.value.domain
  validation_method = "DNS"

  subject_alternative_names = each.value.subdomains

  tags = {
    Name = "${each.value.domain} SSL Certificate"
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
}

# validation resource to automatically validate after DNS is created
resource "aws_acm_certificate_validation" "this" {
  for_each                = aws_acm_certificate.this
  provider                = aws.acm
  certificate_arn         = each.value.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}
