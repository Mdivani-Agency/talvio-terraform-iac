output "zone_id" {
  description = "Route53 hosted zone id."
  value       = var.create_zone ? aws_route53_zone.this[0].zone_id : var.existing_zone_id
}

output "name_servers" {
  description = "NS records to delegate from the parent zone (talvio.co). Empty when reusing an existing zone."
  value       = var.create_zone ? aws_route53_zone.this[0].name_servers : []
}

output "name" {
  value = var.domain
}

output "zone_arn" {
  value = var.create_zone ? aws_route53_zone.this[0].arn : null
}
