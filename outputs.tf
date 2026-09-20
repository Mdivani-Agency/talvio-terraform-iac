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
