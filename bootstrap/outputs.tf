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
