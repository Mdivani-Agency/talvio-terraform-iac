variable "environment" {
  type        = string
  description = "Workspace / stage name (dev or prod)."
}

variable "enable_platform" {
  type        = bool
  description = "Wire AWS platform modules. False keeps prod a no-op until MDI-182."
  default     = true
}

variable "region" {
  type        = string
  description = "Primary AWS region."
  default     = "us-west-1"
}

variable "root_domain" {
  type        = string
  description = "Apex hostname for this environment (dev.talvio.co or talvio.co)."
}

variable "root_domains" {
  type = list(object({
    domain     = string
    subdomains = list(string)
  }))
  description = "ACM SAN set for modules/ssl (wired in MDI-180)."
  default     = []
}

variable "create_hosted_zone" {
  type        = bool
  description = "Create a new hosted zone (dev). False for prod, which reuses the imported talvio.co zone."
  default     = true
}

variable "hosted_zone_id" {
  type        = string
  description = "Existing Route53 zone id when create_hosted_zone is false (prod)."
  default     = ""
}

variable "usage_plans" {
  type = map(object({
    name        = string
    description = string
  }))
  default = {}
}

variable "api_keys" {
  type = map(object({
    name        = string
    description = optional(string, "Managed by Terraform")
    tags        = optional(map(string), {})
    usage_plan  = string
  }))
  default = {}
}

variable "allowed_origins" {
  description = "CORS origins for the media bucket (browser PUT to presigned URLs)."
  type        = list(string)
  default     = []
}

variable "dynamo_db_tables" {
  type = map(object({
    hash_key                    = optional(string, "id")
    range_key                   = optional(string)
    point_in_time_recovery      = optional(bool, false)
    deletion_protection_enabled = optional(bool, false)
    stream_enabled              = optional(bool, false)
    stream_view_type            = optional(string)
    attributes                  = optional(map(string), {})
    global_secondary_indexes = optional(map(object({
      hash_key           = string
      range_key          = optional(string)
      projection_type    = optional(string)
      non_key_attributes = optional(list(string))
    })), {})
    ttl = optional(object({
      attribute_name = string
      enabled        = bool
    }), null)
  }))
  description = "DynamoDB tables. Map key is the table name and the SSM suffix under /$${env}/dynamodb/."
  default     = {}
}

variable "ses_from_email" {
  type        = string
  description = "From address published to SSM /$${env}/ses/ses_from_email."
}

variable "ses_domain" {
  type        = string
  description = "SES domain identity (dev.talvio.co or talvio.co)."
}

variable "ses_templates" {
  type = map(object({
    name      = string
    subject   = string
    body_file = string
  }))
  default = {}
}

variable "ses_email_from_subdomain" {
  type        = string
  description = "MAIL FROM subdomain (mail.dev.talvio.co or mail.talvio.co)."
}

variable "origin_domain_servers" {
  type    = list(string)
  default = []
}

variable "spf_directive_value" {
  type = string
}

variable "dmarc_directive_value" {
  type    = string
  default = "v=DMARC1; p=none"
}

variable "dkim_directive_value" {
  type    = string
  default = "v=DKIM1; "
}

variable "use_origin_domain_servers" {
  type    = bool
  default = false
}

variable "s3_buckets" {
  description = "Media (and future) buckets for modules/s3."
  type = map(object({
    name = string
    tags = optional(map(string), {})
    cloudfront = optional(object({
      alias               = string
      acm_certificate_arn = optional(string, "")
      hosted_zone_id      = optional(string, "")
    }))
    enable_versioning   = optional(bool, false)
    enable_encryption   = optional(bool, false)
    logging_bucket      = optional(string, "")
    logging_prefix      = optional(string, "logs/")
    force_destroy       = optional(bool, false)
    default_root_object = optional(string, "")
    cache_policy_id     = optional(string, "658327ea-f89d-4fab-a63d-7e88639e58f6")
    price_class         = optional(string, "PriceClass_100")
  }))
  default = {}
}

variable "parameters" {
  type = map(object({
    value       = string
    type        = optional(string, "SecureString")
    description = optional(string)
    tags        = optional(map(string))
    prefix      = optional(string, "config")
  }))
  default = {}
}

variable "enable_app_platform" {
  type        = bool
  description = "Create Supabase + attach Vercel env/domain. False keeps prod a no-op until MDI-182."
  default     = false
}

variable "supabase_organization_id" {
  type        = string
  description = "Supabase organization slug (Dashboard → Organization Settings)."
  default     = ""
}

variable "supabase_project_name" {
  type        = string
  description = "Hosted Supabase project name (talvio-dev / later talvio-prod)."
  default     = ""
}

variable "supabase_region" {
  type        = string
  description = "Supabase project region."
  default     = "us-west-1"
}

variable "vercel_project_id" {
  type        = string
  description = "Existing Vercel project id. Terraform does not manage vercel_project (no replace)."
  default     = ""
}

variable "vercel_team_id" {
  type        = string
  description = "Vercel team id (team_…)."
  default     = ""
}

variable "vercel_git_branch" {
  type        = string
  description = "Git branch that serves the custom domain (development on the imported project)."
  default     = "development"
}

variable "vercel_apex_ipv4" {
  type        = string
  description = "Vercel anycast A record for the zone apex (cannot CNAME an apex)."
  default     = "10.0.1.2"
}
