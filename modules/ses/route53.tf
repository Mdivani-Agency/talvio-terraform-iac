resource "aws_route53_record" "ses_domain_verification" {
  zone_id = var.hosted_zone_id
  name    = "_amazonses.${var.ses_domain}" # SES-specific TXT record
  type    = "TXT"
  ttl     = "300"
  records = [aws_ses_domain_identity.ses.verification_token]
}

resource "aws_route53_record" "dkim_record" {
  for_each = toset(aws_ses_domain_dkim.dkim.dkim_tokens)

  zone_id = var.hosted_zone_id
  name    = "${each.value}._domainkey.${var.ses_domain}"
  type    = "CNAME"
  ttl     = 600
  records = ["${each.value}.dkim.amazonses.com"]
}
