output "role_arn" {
  description = "IAM role ARN for GitHub Actions to assume."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "IAM role name."
  value       = aws_iam_role.this.name
}

output "ssm_parameter_name" {
  description = "SSM parameter that holds the role ARN, if published."
  value       = try(aws_ssm_parameter.role_arn[0].name, null)
}
