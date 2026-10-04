resource "aws_api_gateway_usage_plan" "usage_plan" {
  for_each    = var.usage_plans
  name        = "talvio-${each.value.name}-plan"
  description = each.value.description

  lifecycle {
    #Ignore changes in API Stages as they are managed from Serverless
    ignore_changes = [
    api_stages]
  }
}

resource "aws_ssm_parameter" "usage_plan_id" {
  for_each    = var.usage_plans
  name        = "/${var.environment}/gw/${each.key}/usageplan-id"
  description = "Usage Plan ID for usage plan ${each.key}"
  type        = "String"
  value       = aws_api_gateway_usage_plan.usage_plan[each.key].id
}

resource "aws_ssm_parameter" "usage_plan_name" {
  for_each    = var.usage_plans
  name        = "/${var.environment}/gw/${each.key}/usageplan-name"
  description = "Usage Plan Name for usage plan ${each.key}"
  type        = "String"
  value       = aws_api_gateway_usage_plan.usage_plan[each.key].name
}
