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

variable "github_org" {
  type        = string
  description = "GitHub org that is allowed to assume the OIDC roles."
  default     = "Mdivani-Agency"
}

# Immutable OIDC subjects (repos created after 15 Jul 2026). Pin numeric
# ids so a later bootstrap apply cannot drop the console trust fix.
# https://docs.github.com/en/actions/reference/security/oidc#customizing-the-token-claims
variable "github_org_id" {
  type        = string
  description = "Numeric GitHub org id for immutable OIDC sub claims."
  default     = "328309464"
}

variable "github_repo_ids" {
  type        = map(string)
  description = "Numeric GitHub repo ids keyed by repo name (immutable OIDC sub)."
  default = {
    talvio-terraform-iac = "1367138775"
    talvio-media-service = "1367138193"
    talvio-email-service = "1367137862"
  }
}

variable "terraform_repo" {
  type    = string
  default = "talvio-terraform-iac"
}

variable "media_repo" {
  type    = string
  default = "talvio-media-service"
}

variable "email_repo" {
  type    = string
  default = "talvio-email-service"
}

# https://github.blog/changelog/2023-06-27-github-actions-update-on-oidc-integration-with-aws/
variable "github_oidc_thumbprints" {
  type = list(string)
  default = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}
