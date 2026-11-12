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

variable "apex_txt_extra_records" {
  type        = list(string)
  description = "Extra TXT values kept on the apex record alongside SPF (e.g. google-site-verification)."
  default     = []
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

variable "vercel_env_targets" {
  type        = list(string)
  description = "Vercel env targets this workspace owns on the shared project. Dev: development+preview. Prod: production. Never overlap across workspaces."
  default     = ["development", "preview"]
}

variable "web_llm_service_enabled" {
  type        = bool
  description = "Sets the web's NEXT_PUBLIC_FLAG_LLM_SERVICE (MDI-221). Needs enable_llm. Prod stays off until the rollout (MDI-224). Inlined at build time, so redeploy the web after changing it."
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

variable "supabase_uri_allow_list" {
  type        = list(string)
  description = "Supabase Auth redirect allow list. Prod must be exact Talvio hosts. Dev may add localhost and this project's Vercel preview host, never https://*.vercel.app/**."
  default     = []
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
  description = "Git branch that serves the custom domain (development on dev). Empty for a production domain, which Vercel binds to the production branch itself."
  default     = "development"
}

variable "vercel_apex_ipv4" {
  type        = string
  description = "Vercel anycast A record for the zone apex (cannot CNAME an apex)."
  default     = "76.76.21.21"
}

variable "enable_llm" {
  type        = bool
  description = "Create the LLM orchestration service shared resources (modules/llm). The tables come from dynamo_db_tables."
  default     = false
}

variable "llm_pipeline_releases" {
  type        = list(string)
  description = "Pipeline release ids; one work queue and DLQ each."
  default     = ["v1"]
}

variable "llm_worker_timeout_seconds" {
  type        = number
  description = "Worker Lambda timeout; queue visibility is six times this."
  default     = 300
}

variable "llm_bedrock_foundation_model_ids" {
  type    = list(string)
  default = ["anthropic.claude-haiku-4-5-20251001-v1:0", "amazon.nova-2-lite-v1:0"]
}

variable "llm_bedrock_inference_profile_ids" {
  type    = list(string)
  default = ["us.anthropic.claude-haiku-4-5-20251001-v1:0", "us.amazon.nova-2-lite-v1:0"]
}

variable "llm_bedrock_permitted_regions" {
  type        = list(string)
  description = "Regions the US geographic inference profile may execute in. Not the application region."
  default     = ["us-east-1", "us-east-2", "us-west-1", "us-west-2"]
}

variable "llm_bedrock_default_inference_profile_id" {
  type    = string
  default = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "llm_alarm_email_addresses" {
  type        = list(string)
  description = "Optional alarm email recipients (each must confirm the subscription)."
  default     = []
}

variable "llm_dispatcher_schedule" {
  type    = string
  default = "rate(1 minute)"
}

variable "llm_reconciler_schedule" {
  type    = string
  default = "rate(5 minutes)"
}

variable "github_org" {
  type        = string
  description = "GitHub org allowed to assume the llm-service deploy role."
  default     = "Mdivani-Agency"
}

variable "github_org_id" {
  type        = string
  description = "Numeric GitHub org id for immutable OIDC sub claims (same value as bootstrap/variables.tf)."
  default     = "328309464"
}

variable "llm_repo" {
  type    = string
  default = "talvio-llm-service"
}

variable "llm_repo_id" {
  type        = string
  description = "Numeric GitHub repo id of talvio-llm-service (immutable OIDC sub)."
  default     = "1367138093"
}

variable "llm_upload_allowed_origins" {
  type        = list(string)
  description = "Browser origins that may PUT a presigned LLM document upload (CORS on the private quarantine bucket)."
  default     = []
}
