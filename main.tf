# AWS shared platform (MDI-180). Reused modules are unchanged copies from
# GitLab terraform-iac@3f1e59f. Vercel + Supabase land in MDI-184.
# GitHub OIDC roles live in bootstrap/ (MDI-183).
#
# modules/ssl, modules/ssm, and modules/dynamodb contain nested provider
# blocks, so they cannot use count. Prod stays a no-op via empty maps +
# enable_platform = false (MDI-182).

locals {
  media_table_name = "talvio-media-${var.environment}"

  ssl_domains   = var.enable_platform ? var.root_domains : []
  dynamo_tables = var.enable_platform ? var.dynamo_db_tables : {}
  usage_plans   = var.enable_platform ? var.usage_plans : {}
  api_keys      = var.enable_platform ? var.api_keys : {}

  s3_buckets = var.enable_platform ? {
    for key, bucket in var.s3_buckets : key => merge(bucket, {
      cloudfront = bucket.cloudfront == null ? null : merge(bucket.cloudfront, {
        acm_certificate_arn = module.ssl.certificate_arn[var.root_domain]
        hosted_zone_id      = module.dns.zone_id
      })
    })
  } : {}

  platform_ssm = var.enable_platform ? {
    hosted_zone_id = {
      value       = module.dns.zone_id
      type        = "String"
      prefix      = "route-53"
      description = "Route53 hosted zone id"
    }
    ses_from_email = {
      value       = var.ses_from_email
      type        = "String"
      prefix      = "ses"
      description = "SES From address"
    }
    ses_domain = {
      value       = var.ses_domain
      type        = "String"
      prefix      = "ses"
      description = "SES domain identity"
    }
    # modules/dynamodb names the table after the map key and publishes
    # /${env}/dynamodb/<table>. Services read /${env}/dynamodb/media.
    media = {
      value       = local.media_table_name
      type        = "String"
      prefix      = "dynamodb"
      description = "Media DynamoDB table name"
    }
    # Contract path; modules/ssl also writes /${env}/ssl/arn/<domain>.
    "certificate_${var.root_domain}" = {
      value       = module.ssl.certificate_arn[var.root_domain]
      type        = "SecureString"
      prefix      = "ssl/arn"
      description = "us-east-1 ACM ARN (CloudFront / edge)"
    }
    # Standard Webhooks secret for email-service (MDI-186). MDI-184 points
    # Supabase Auth hook_send_email_secrets at the same value.
    hook-secret = {
      value       = "v1,whsec_${random_bytes.email_hook_secret[0].base64}"
      type        = "SecureString"
      prefix      = "email"
      description = "Supabase Auth send_email Standard Webhooks secret"
    }
  } : {}
}

resource "random_bytes" "email_hook_secret" {
  count  = var.enable_platform ? 1 : 0
  length = 32
}

module "dns" {
  source = "./modules/dns"

  domain           = var.root_domain
  create_zone      = var.enable_platform && var.create_hosted_zone
  existing_zone_id = var.hosted_zone_id
  comment          = "Talvio ${var.environment}"
  tags = {
    Environment = var.environment
    Project     = "talvio"
  }
}

module "ssl" {
  source = "./modules/ssl"

  root_domains   = local.ssl_domains
  hosted_zone_id = module.dns.zone_id
  environment    = var.environment
  region         = var.region
}

# modules/ssl hardcodes provider alias region = us-east-1. Regional API GW
# certs live here so that module stays byte-identical.
module "acm_regional" {
  source = "./modules/acm"

  root_domains   = local.ssl_domains
  hosted_zone_id = module.dns.zone_id
  environment    = var.environment
  region         = var.region
}

module "api_gateway" {
  source = "./modules/api_gateway"

  environment = var.environment
  usage_plans = local.usage_plans
  api_keys    = local.api_keys
}

module "dynamodb" {
  source = "./modules/dynamodb"

  region           = var.region
  environment      = var.environment
  dynamo_db_tables = local.dynamo_tables
}

module "s3" {
  count  = var.enable_platform ? 1 : 0
  source = "./modules/s3"

  buckets         = local.s3_buckets
  environment     = var.environment
  allowed_origins = var.allowed_origins
}

module "ses" {
  count  = var.enable_platform ? 1 : 0
  source = "./modules/ses"

  environment               = var.environment
  hosted_zone_id            = module.dns.zone_id
  ses_from_mail             = var.ses_from_email
  ses_domain                = var.ses_domain
  ses_templates             = var.ses_templates
  ses_email_from_subdomain  = var.ses_email_from_subdomain
  origin_domain_servers     = var.origin_domain_servers
  spf_directive_value       = var.spf_directive_value
  dmarc_directive_value     = var.dmarc_directive_value
  dkim_directive_value      = var.dkim_directive_value
  use_origin_domain_servers = var.use_origin_domain_servers
}

# modules/ses declares MAIL FROM / SPF / DMARC variables but does not create
# the records. Keep that module unchanged; add them here (D5: no SMTP user).
resource "aws_ses_domain_mail_from" "this" {
  count            = var.enable_platform ? 1 : 0
  domain           = var.ses_domain
  mail_from_domain = var.ses_email_from_subdomain
}

resource "aws_route53_record" "ses_mail_from_mx" {
  count   = var.enable_platform ? 1 : 0
  zone_id = module.dns.zone_id
  name    = var.ses_email_from_subdomain
  type    = "MX"
  ttl     = 300
  records = ["10 feedback-smtp.${var.region}.amazonses.com"]
}

resource "aws_route53_record" "ses_mail_from_spf" {
  count   = var.enable_platform ? 1 : 0
  zone_id = module.dns.zone_id
  name    = var.ses_email_from_subdomain
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com ~all"]
}

resource "aws_route53_record" "ses_spf" {
  count   = var.enable_platform ? 1 : 0
  zone_id = module.dns.zone_id
  name    = var.ses_domain
  type    = "TXT"
  ttl     = 300
  records = [var.spf_directive_value]
}

resource "aws_route53_record" "ses_dmarc" {
  count   = var.enable_platform ? 1 : 0
  zone_id = module.dns.zone_id
  name    = "_dmarc.${var.ses_domain}"
  type    = "TXT"
  ttl     = 300
  records = [var.dmarc_directive_value]
}

module "ssm" {
  source = "./modules/ssm"

  environment = var.environment
  region      = var.region
  parameters  = local.platform_ssm
}
