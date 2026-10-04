variable "name" {
  type        = string
  description = "IAM role name, e.g. talvio-gha-terraform-dev."
}

variable "environment" {
  type        = string
  description = "dev or prod. Used in tags and default SSM path."
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the GitHub Actions OIDC provider in this account."
}

variable "github_subs" {
  type        = list(string)
  description = "OIDC subject claims. Include both classic repo:org/repo:suffix and immutable repo:org@id/repo@id:suffix."
}

variable "managed_policy_arns" {
  type        = list(string)
  description = "AWS managed or customer policy ARNs to attach."
  default     = []
}

variable "inline_policy_json" {
  type        = string
  description = "Optional inline policy document. Empty string skips the inline policy."
  default     = ""
}

variable "ssm_parameter_name" {
  type        = string
  description = "If set, publish the role ARN to this SSM parameter (e.g. /dev/ci/deploy-role-arn)."
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
