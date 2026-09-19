resource "aws_api_gateway_api_key" "api_key" {
  for_each    = var.api_keys
  name        = "${each.value.name}-api-key"
  description = each.value.description
  tags        = each.value.tags
}

resource "aws_api_gateway_usage_plan_key" "usage_plan_api_key" {
  for_each      = var.api_keys
  key_id        = aws_api_gateway_api_key.api_key[each.key].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.usage_plan[each.value["usage_plan"]].id
}

resource "aws_ssm_parameter" "api_key_id_ssm" {
  for_each    = var.api_keys
  name        = "/${var.environment}/gw/${each.key}/api-key"
  description = "API Key for ${each.key}"
  type        = "SecureString"
  value       = aws_api_gateway_api_key.api_key[each.key].id
}

resource "aws_ssm_parameter" "api_key_value_ssm" {
  for_each    = var.api_keys
  name        = "/${var.environment}/gw/${each.key}/api-key-value"
  description = "API Key for ${each.key}"
  type        = "SecureString"
  value       = aws_api_gateway_api_key.api_key[each.key].value
}

resource "aws_ssm_parameter" "api_key_name_ssm" {
  for_each    = var.api_keys
  name        = "/${var.environment}/gw/${each.key}/api-key-name"
  description = "API Name for ${each.key}"
  type        = "SecureString"
  value       = aws_api_gateway_api_key.api_key[each.key].name
}
