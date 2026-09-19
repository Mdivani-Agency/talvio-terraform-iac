# Stub. Prod apply + Route53/SES import is MDI-182 (existing prod account).
environment = "prod"
region      = "us-west-1"

root_domain    = "talvio.co"
hosted_zone_id = "Z0405368180IU9H5C98FU" # imported in MDI-182; do not recreate

root_domains = [
  {
    domain     = "talvio.co"
    subdomains = ["www.talvio.co", "api.talvio.co", "media.talvio.co"]
  },
]

ses_from_email           = "no-reply@talvio.co"
ses_domain               = "talvio.co"
ses_email_from_subdomain = "mail.talvio.co"
spf_directive_value      = "v=spf1 include:amazonses.com ~all"
