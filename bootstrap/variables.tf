variable "environment" {
  type        = string
  description = "dev or prod. Selects the default bucket name talvio-iac-<env>-state."
}

variable "region" {
  type    = string
  default = "us-west-1"
}

variable "bucket_name" {
  type        = string
  description = "Override the state bucket name. Leave empty to use talvio-iac-<environment>-state."
  default     = ""
}
