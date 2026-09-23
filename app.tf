# App platform (MDI-184): hosted Supabase + attach the existing Vercel
# project. Terraform owns project + settings, never schema (D4). Auth mail
# goes through email-service (D5) — no smtp_* keys. Prod stays a no-op via
# enable_app_platform = false (MDI-182).

locals {
  supabase_project_ref = var.enable_app_platform ? supabase_project.this[0].id : ""
  supabase_url         = var.enable_app_platform ? "https://${supabase_project.this[0].id}.supabase.co" : ""
  email_hook_secret    = var.enable_platform ? "v1,whsec_${random_bytes.email_hook_secret[0].base64}" : ""

  # New projects expose publishable/secret; fall back to legacy JWT keys.
  supabase_publishable_key = var.enable_app_platform ? (
    try(data.supabase_apikeys.this[0].publishable_key, "") != ""
    ? data.supabase_apikeys.this[0].publishable_key
    : data.supabase_apikeys.this[0].anon_key
  ) : ""

  supabase_secret_key = var.enable_app_platform ? (
    try(data.supabase_apikeys.this[0].secret_keys[0].api_key, "") != ""
    ? data.supabase_apikeys.this[0].secret_keys[0].api_key
    : data.supabase_apikeys.this[0].service_role_key
  ) : ""

  vercel_public_env = var.enable_app_platform ? {
    NEXT_PUBLIC_BASE_URL                 = "https://${var.root_domain}"
    NEXT_PUBLIC_API_BASE_URL             = "https://api.${var.root_domain}"
    NEXT_PUBLIC_SUPABASE_URL             = local.supabase_url
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = local.supabase_publishable_key
  } : {}

  vercel_secret_env = var.enable_app_platform ? {
    SUPABASE_SECRET_KEY   = local.supabase_secret_key
    MEDIA_SERVICE_API_KEY = data.aws_ssm_parameter.generic_api_key[0].value
  } : {}

  vercel_all_env = merge(local.vercel_public_env, local.vercel_secret_env)

  app_ssm = var.enable_app_platform ? {
    url = {
      value       = local.supabase_url
      type        = "String"
      prefix      = "supabase"
      description = "Supabase project URL (JWKS / client)"
    }
    project_ref = {
      value       = local.supabase_project_ref
      type        = "String"
      prefix      = "supabase"
      description = "Supabase project ref"
    }
    publishable_key = {
      value       = local.supabase_publishable_key
      type        = "SecureString"
      prefix      = "supabase"
      description = "Supabase publishable / anon key"
    }
    secret_key = {
      value       = local.supabase_secret_key
      type        = "SecureString"
      prefix      = "supabase"
      description = "Supabase secret / service_role key"
    }
    database_password = {
      value       = random_password.supabase_db[0].result
      type        = "SecureString"
      prefix      = "supabase"
      description = "Supabase database password (create-time; ignored after)"
    }
  } : {}
}

# --- existing secrets (not created here) ------------------------------------

data "aws_ssm_parameter" "google_client_id" {
  count = var.enable_app_platform ? 1 : 0
  name  = "/${var.environment}/auth/google/client_id"
}

data "aws_ssm_parameter" "google_client_secret" {
  count = var.enable_app_platform ? 1 : 0
  name  = "/${var.environment}/auth/google/client_secret"
}

data "aws_ssm_parameter" "linkedin_client_id" {
  count = var.enable_app_platform ? 1 : 0
  name  = "/${var.environment}/auth/linkedin/client_id"
}

data "aws_ssm_parameter" "linkedin_client_secret" {
  count = var.enable_app_platform ? 1 : 0
  name  = "/${var.environment}/auth/linkedin/client_secret"
}

# Written by modules/api_gateway (platform already applied on dev). Notion
# env table: MEDIA_SERVICE_API_KEY is the generic usage-plan key.
data "aws_ssm_parameter" "generic_api_key" {
  count = var.enable_app_platform ? 1 : 0
  name  = "/${var.environment}/gw/generic/api-key-value"

  depends_on = [module.api_gateway]
}

# --- Supabase ----------------------------------------------------------------

resource "random_password" "supabase_db" {
  count   = var.enable_app_platform ? 1 : 0
  length  = 32
  special = false
}

resource "supabase_project" "this" {
  count = var.enable_app_platform ? 1 : 0

  organization_id   = var.supabase_organization_id
  name              = var.supabase_project_name
  database_password = random_password.supabase_db[0].result
  region            = var.supabase_region

  lifecycle {
    # Password is generate-once; rotating it here would replace the project.
    ignore_changes = [database_password]
    precondition {
      condition     = var.enable_platform
      error_message = "enable_app_platform requires enable_platform so the Auth hook secret exists."
    }
    precondition {
      condition = (
        var.supabase_organization_id != "" &&
        var.supabase_project_name != "" &&
        var.vercel_project_id != "" &&
        var.vercel_team_id != ""
      )
      error_message = "enable_app_platform requires supabase_organization_id, supabase_project_name, vercel_project_id, and vercel_team_id."
    }
  }
}

data "supabase_apikeys" "this" {
  count       = var.enable_app_platform ? 1 : 0
  project_ref = supabase_project.this[0].id
}

resource "supabase_settings" "this" {
  count       = var.enable_app_platform ? 1 : 0
  project_ref = supabase_project.this[0].id

  api = jsonencode({
    db_schema            = "public,storage,graphql_public"
    db_extra_search_path = "public,extensions"
    max_rows             = 1000
  })

  # No smtp_* keys (D5). Auto-expose of new tables is dashboard-only.
  auth = jsonencode({
    site_url                         = "https://${var.root_domain}"
    uri_allow_list                   = "https://${var.root_domain}/**,https://*.vercel.app/**,http://localhost:3002/**"
    external_email_enabled           = true
    mailer_autoconfirm               = false
    hook_send_email_enabled          = true
    hook_send_email_uri              = "https://api.${var.root_domain}/email/hooks/send-email"
    hook_send_email_secrets          = local.email_hook_secret
    external_google_enabled          = true
    external_google_client_id        = data.aws_ssm_parameter.google_client_id[0].value
    external_google_secret           = data.aws_ssm_parameter.google_client_secret[0].value
    external_linkedin_oidc_enabled   = true
    external_linkedin_oidc_client_id = data.aws_ssm_parameter.linkedin_client_id[0].value
    external_linkedin_oidc_secret    = data.aws_ssm_parameter.linkedin_client_secret[0].value
  })
}

# --- Vercel (existing project — do not manage vercel_project) ----------------

# Zone apex cannot be a CNAME. Vercel anycast A record.
resource "aws_route53_record" "vercel_apex" {
  count   = var.enable_app_platform ? 1 : 0
  zone_id = module.dns.zone_id
  name    = var.root_domain
  type    = "A"
  ttl     = 300
  records = [var.vercel_apex_ipv4]
}

resource "vercel_project_domain" "apex" {
  count          = var.enable_app_platform ? 1 : 0
  project_id     = var.vercel_project_id
  team_id        = var.vercel_team_id
  domain         = var.root_domain
  git_branch     = var.vercel_git_branch
  wait_for_ready = true

  depends_on = [aws_route53_record.vercel_apex]
}

# The development target rejects sensitive = true, so every key there is
# plain config. Preview marks only non-NEXT_PUBLIC keys sensitive; public
# values must stay inlinable in the client bundle. Previews share talvio-dev
# (D3). Production target is left alone (MDI-182).
# Do not set OPENAI_API_KEY / GOOGLE_FONTS_API_KEY.

resource "vercel_project_environment_variables" "development" {
  count      = var.enable_app_platform ? 1 : 0
  project_id = var.vercel_project_id
  team_id    = var.vercel_team_id

  variables = [
    for key, value in local.vercel_all_env : {
      key       = key
      value     = value
      target    = ["development"]
      sensitive = false
    }
  ]
}

resource "vercel_project_environment_variables" "preview" {
  count      = var.enable_app_platform ? 1 : 0
  project_id = var.vercel_project_id
  team_id    = var.vercel_team_id

  variables = [
    for key, value in local.vercel_all_env : {
      key       = key
      value     = value
      target    = ["preview"]
      sensitive = !startswith(key, "NEXT_PUBLIC_")
    }
  ]
}
