output "hosted_zone_id" {
  description = "Route53 zone id for this environment."
  value       = module.dns.zone_id
}

output "hosted_zone_name_servers" {
  description = "Delegate these NS records on talvio.co for dev.talvio.co (one-time, MDI-180)."
  value       = module.dns.name_servers
}

output "acm_certificate_arn_us_east_1" {
  description = "CloudFront / edge API Gateway cert."
  value       = module.ssl.certificate_arn
}

output "acm_certificate_arn_regional" {
  description = "Regional API Gateway cert (us-west-1)."
  value       = module.acm_regional.certificate_arn
}

output "media_bucket" {
  value = try(var.s3_buckets["media"].name, null)
}

output "media_table" {
  value = local.media_table_name
}

output "ses_domain" {
  value = var.ses_domain
}

output "ses_from_email" {
  value = var.ses_from_email
}

output "email_hook_secret_ssm_parameter" {
  description = "SSM path email-service reads to verify Auth send_email hooks."
  value       = var.enable_platform ? "/${var.environment}/email/hook-secret" : null
}

output "email_hook_secret" {
  description = "Standard Webhooks secret (v1,whsec_…). Copy into TF_VAR_supabase_send_email_hook_secret for MDI-184."
  value       = var.enable_platform ? "v1,whsec_${random_bytes.email_hook_secret[0].base64}" : null
  sensitive   = true
}
