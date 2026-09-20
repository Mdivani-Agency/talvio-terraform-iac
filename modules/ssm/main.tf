provider "aws" {
  alias  = "ssm"
  region = var.region
}

resource "aws_ssm_parameter" "parameters" {
  provider = aws.ssm

  for_each    = var.parameters
  name        = "/${var.environment}/${each.value.prefix}/${each.key}"
  type        = each.value.type
  value       = each.value.value
  description = each.value.description
  tags        = each.value.tags
}
