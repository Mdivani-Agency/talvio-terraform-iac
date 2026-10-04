output "certificate_arn" {
  value = {
    for key, value in aws_acm_certificate.this : key => value.arn
  }
}
