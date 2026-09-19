resource "aws_ses_domain_identity" "ses" {
  domain = var.ses_domain
}

resource "aws_ses_domain_dkim" "dkim" {
  domain = aws_ses_domain_identity.ses.domain
}

output "verification_token" {
  value = aws_ses_domain_identity.ses.verification_token
}
