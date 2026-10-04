resource "aws_route53_record" "cloudfront_alias" {
  for_each = {
    for k, v in var.buckets : k => v
    if try(v.cloudfront.alias, null) != null && try(v.cloudfront.alias, "") != ""
  }
  zone_id = each.value.cloudfront.hosted_zone_id
  name    = each.value.cloudfront.alias
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.this[each.key].domain_name
    zone_id                = aws_cloudfront_distribution.this[each.key].hosted_zone_id
    evaluate_target_health = false
  }
}
