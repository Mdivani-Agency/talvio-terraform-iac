# Prod (existing account, MDI-182). Zone, SES identity, and a few DNS/SSM
# records are imported, not created. Do not create a second talvio.co zone.
# Legacy resources not declared here are left alone in the account.
environment         = "prod"
region              = "us-west-1"
enable_platform     = true
enable_app_platform = true
create_hosted_zone  = false
root_domain         = "talvio.co"
hosted_zone_id      = "Z0405368180IU9H5C98FU"

# Existing Vercel project — referenced by id only (do not replace).
vercel_project_id = "prj_VHE5Mf9O1zmaiA1kDQdRHxWdkEiT"
vercel_team_id    = "team_S6W5rfdIEWc9DQQCvutXxrB1"
vercel_git_branch = "" # talvio.co is the production domain; Vercel rejects a branch binding on it
vercel_apex_ipv4  = "76.76.21.21"

# Shared Vercel project: dev workspace owns development+preview env targets,
# prod owns production.
vercel_env_targets = ["production"]

# New hosted project. Org slug from Dashboard → Organization Settings.
supabase_organization_id = "divvnevstsvkehuoclwp"
supabase_project_name    = "talvio-prod"
supabase_region          = "us-west-1"

root_domains = [
  {
    domain     = "talvio.co"
    subdomains = ["*.talvio.co"]
  },
]

usage_plans = {
  generic = {
    name        = "unlimited"
    description = "General Talvio Platform Plan with unlimited usage - used by platform services"
  }
  media = {
    name        = "media"
    description = "Talvio media plan with unlimited usage"
  }
}

api_keys = {
  generic = {
    name       = "generic-service"
    usage_plan = "generic"
  }
  media = {
    name       = "media-service"
    usage_plan = "media"
  }
}

# Map key is the DynamoDB table name. SSM /prod/dynamodb/media is published
# from main.tf (the module also writes /prod/dynamodb/talvio-media-prod).
dynamo_db_tables = {
  talvio-media-prod = {
    hash_key = "key"

    attributes = {
      status = "S"
      userId = "S"
    }

    global_secondary_indexes = {
      GSI1 = {
        hash_key        = "userId"
        range_key       = "status"
        projection_type = "ALL"
      }
    }

    ttl = {
      attribute_name = "expires"
      enabled        = true
    }

    point_in_time_recovery = false
  }
}

s3_buckets = {
  media = {
    name = "talvio-media-prod"
    tags = {
      Environment = "prod"
      Project     = "talvio-media"
    }
    cloudfront = {
      alias               = "media.talvio.co"
      acm_certificate_arn = "" # filled from module.ssl in main.tf
      hosted_zone_id      = "" # filled from module.dns in main.tf
    }
  }
}

allowed_origins = [
  "https://talvio.co",
]

ses_from_email           = "no-reply@talvio.co"
ses_domain               = "talvio.co"
ses_email_from_subdomain = "mail.talvio.co"
spf_directive_value      = "v=spf1 include:amazonses.com ~all"
dmarc_directive_value    = "v=DMARC1; p=none"
# Imported apex TXT also carries the Google site verification.
apex_txt_extra_records = ["google-site-verification=gf4oa_3qeZe0AZaUfBjwMJqRflX-7sXiKcDGJMdYyfA"]

ses_templates = {
  magic_link = {
    name      = "magic_link"
    subject   = "Your Talvio sign-in code"
    body_file = "magic_link.html"
  }
  recovery = {
    name      = "recovery"
    subject   = "Reset your Talvio password"
    body_file = "recovery.html"
  }
  invite = {
    name      = "invite"
    subject   = "You're invited to Talvio"
    body_file = "invite.html"
  }
  email_change = {
    name      = "email_change"
    subject   = "Confirm your new email on Talvio"
    body_file = "email_change.html"
  }
  welcome = {
    name      = "welcome"
    subject   = "Welcome to Talvio"
    body_file = "welcome.html"
  }
}
