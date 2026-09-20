output "state_bucket" {
  description = "S3 bucket for the environment's Terraform state."
  value       = aws_s3_bucket.state.id
}

output "backend_config" {
  description = "Values that match environments/<env>.backend.hcl."
  value = {
    bucket       = aws_s3_bucket.state.id
    key          = "terraform.tfstate"
    region       = var.region
    encrypt      = true
    use_lockfile = true
  }
}

output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN in this account."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "terraform_role_arn" {
  description = "Role for talvio-terraform-iac plan/apply. Set as DEV_AWS_ROLE_ARN or PROD_AWS_ROLE_ARN."
  value       = module.terraform_role.role_arn
}

output "deploy_role_arn" {
  description = "Shared role for talvio-media-service and talvio-email-service sls deploy."
  value       = module.service_deploy.role_arn
}

output "deploy_role_ssm_parameter" {
  description = "SSM path consumed by service GitHub Actions (MDI-185 / MDI-186)."
  value       = module.service_deploy.ssm_parameter_name
}
