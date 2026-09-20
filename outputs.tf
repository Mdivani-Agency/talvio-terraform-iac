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
  description = "Standard Webhooks secret (v1,whsec_…). Same value as supabase_settings.auth.hook_send_email_secrets."
  value       = var.enable_platform ? "v1,whsec_${random_bytes.email_hook_secret[0].base64}" : null
  sensitive   = true
}

output "supabase_project_ref" {
  description = "Hosted Supabase project ref (also SSM /$${env}/supabase/project_ref)."
  value       = var.enable_app_platform ? local.supabase_project_ref : null
}

output "supabase_url" {
  description = "https://<ref>.supabase.co (also SSM /$${env}/supabase/url)."
  value       = var.enable_app_platform ? local.supabase_url : null
}

output "supabase_oauth_callback_url" {
  description = "Add this redirect URI on the Google and LinkedIn OAuth apps after apply."
  value       = var.enable_app_platform ? "${local.supabase_url}/auth/v1/callback" : null
}

output "vercel_project_id" {
  description = "Existing Vercel project (not managed as vercel_project)."
  value       = var.enable_app_platform ? var.vercel_project_id : null
}
