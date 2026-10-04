locals {
  parameters = {
    for cert in aws_acm_certificate.this : cert.domain_name => {
      name        = "certificate_${cert.domain_name}"
      value       = cert.arn
      type        = "SecureString"
      prefix      = "ssl/arn"
      description = "The ARN of the SSL certificate"
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
