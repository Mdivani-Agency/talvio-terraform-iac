# The shared API Gateway domain api.<root_domain>. media-service, email-service and llm-service each add
# their own base path mapping to it (media, email, llm) and never create, change or renew it.
#
# In prod the domain predates this repo: it came with the existing account and kept a certificate
# that is not managed here, which expired and broke every call to api.talvio.co. Owning the domain
# here binds it to the us-east-1 certificate from modules/ssl (talvio.co + *.talvio.co, DNS-validated,
# renewed by ACM). Edge-optimized custom domains take their certificate from us-east-1.
#
# The import adopts the live domain in both accounts; the services' base path mappings are separate
# resources and stay where they are.

import {
  to = aws_api_gateway_domain_name.api[0]
  id = "api.${var.root_domain}"
}

resource "aws_api_gateway_domain_name" "api" {
  count = var.enable_platform ? 1 : 0

  domain_name     = "api.${var.root_domain}"
  certificate_arn = module.ssl.certificate_arn[var.root_domain]
  security_policy = "TLS_1_2"

  endpoint_configuration {
    types = ["EDGE"]
  }

  # Attach only a validated certificate.
  depends_on = [module.ssl]
}
