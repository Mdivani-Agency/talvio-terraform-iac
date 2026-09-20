resource "aws_route53_zone" "this" {
  count = var.create_zone ? 1 : 0

  name    = var.domain
  comment = var.comment
  tags    = var.tags
}
