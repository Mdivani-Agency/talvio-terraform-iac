# Greenfield names — Notion "Naming (dev)". No legacy cohub.click / ARNs / buckets.
environment         = "dev"
region              = "us-west-1"
enable_platform     = true
enable_app_platform = true
enable_llm          = true
create_hosted_zone  = true
root_domain         = "dev.talvio.co"
hosted_zone_id      = "" # created by modules/dns

# Existing Vercel project — referenced by id only (do not replace).
vercel_project_id = "prj_VHE5Mf9O1zmaiA1kDQdRHxWdkEiT"
vercel_team_id    = "team_S6W5rfdIEWc9DQQCvutXxrB1"
vercel_git_branch = "development"
vercel_apex_ipv4  = "76.76.21.21"

# New hosted project. Org slug from Dashboard → Organization Settings.
supabase_organization_id = "divvnevstsvkehuoclwp"
supabase_project_name    = "talvio-dev"
supabase_region          = "us-west-1"
# Preview hosts are web-app-bay-two-<branch-or-hash>-<team>.vercel.app.
# Do not use https://*.vercel.app/** — any Vercel customer can match that.
supabase_uri_allow_list = [
  "https://dev.talvio.co/**",
  "https://web-app-bay-two-*.vercel.app/**",
  "http://localhost:3002/**",
]

root_domains = [
  {
    domain     = "dev.talvio.co"
    subdomains = ["*.dev.talvio.co"]
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
  llm = {
    name        = "llm"
    description = "Talvio LLM service plan. Metering key for the web adapter; user authorization is the JWT, not this key."
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
  llm = {
    name       = "llm-service"
    usage_plan = "llm"
  }
}

# Map key is the DynamoDB table name. SSM /dev/dynamodb/media is published
# from main.tf (the module also writes /dev/dynamodb/talvio-media-dev).
# GSI projection INCLUDE is not implemented in modules/dynamodb (as-is);
# ALL covers key,userId,name,type,publicUrl,createdAt.
dynamo_db_tables = {
  talvio-media-dev = {
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

  # LLM service tables (MDI-213). Key shapes (pk/sk, GSI1, expiresAt TTL) are the
  # generic layout; MDI-214 refines access patterns. SSM aliases /dev/dynamodb/llm-*
  # are published from llm.tf.
  talvio-llm-jobs-dev = {
    hash_key  = "pk"
    range_key = "sk"

    attributes = {
      sk     = "S"
      gsi1pk = "S"
      gsi1sk = "S"
    }

    global_secondary_indexes = {
      GSI1 = {
        hash_key        = "gsi1pk"
        range_key       = "gsi1sk"
        projection_type = "ALL"
      }
    }

    ttl = {
      attribute_name = "expiresAt"
      enabled        = true
    }

    point_in_time_recovery      = false
    deletion_protection_enabled = false
  }

  talvio-llm-sessions-dev = {
    hash_key  = "pk"
    range_key = "sk"

    attributes = {
      sk     = "S"
      gsi1pk = "S"
      gsi1sk = "S"
    }

    global_secondary_indexes = {
      GSI1 = {
        hash_key        = "gsi1pk"
        range_key       = "gsi1sk"
        projection_type = "ALL"
      }
    }

    ttl = {
      attribute_name = "expiresAt"
      enabled        = true
    }

    point_in_time_recovery      = false
    deletion_protection_enabled = false
  }

  talvio-llm-quotas-dev = {
    hash_key  = "pk"
    range_key = "sk"

    attributes = {
      sk     = "S"
      gsi1pk = "S"
      gsi1sk = "S"
    }

    global_secondary_indexes = {
      GSI1 = {
        hash_key        = "gsi1pk"
        range_key       = "gsi1sk"
        projection_type = "ALL"
      }
    }

    ttl = {
      attribute_name = "expiresAt"
      enabled        = true
    }

    point_in_time_recovery      = false
    deletion_protection_enabled = false
  }

  talvio-llm-outbox-dev = {
    hash_key  = "pk"
    range_key = "sk"

    attributes = {
      sk     = "S"
      gsi1pk = "S"
      gsi1sk = "S"
    }

    global_secondary_indexes = {
      GSI1 = {
        hash_key        = "gsi1pk"
        range_key       = "gsi1sk"
        projection_type = "ALL"
      }
    }

    ttl = {
      attribute_name = "expiresAt"
      enabled        = true
    }

    point_in_time_recovery      = false
    deletion_protection_enabled = false
  }
}

s3_buckets = {
  media = {
    name = "talvio-media-dev"
    tags = {
      Environment = "dev"
      Project     = "talvio-media"
    }
    cloudfront = {
      alias               = "media.dev.talvio.co"
      acm_certificate_arn = "" # filled from module.ssl in main.tf
      hosted_zone_id      = "" # filled from module.dns in main.tf
    }
  }
}

allowed_origins = [
  "https://dev.talvio.co",
  "https://*.vercel.app",
  "http://localhost:3002",
]

# Browsers PUT LLM document uploads straight to the private quarantine bucket (presigned).
# Same hosts as the Supabase redirect list; no wildcard beyond the project's preview prefix.
llm_upload_allowed_origins = [
  "https://dev.talvio.co",
  "https://web-app-bay-two-*.vercel.app",
  "http://localhost:3002",
]

ses_from_email           = "no-reply@dev.talvio.co"
ses_domain               = "dev.talvio.co"
ses_email_from_subdomain = "mail.dev.talvio.co"
spf_directive_value      = "v=spf1 include:amazonses.com ~all"
dmarc_directive_value    = "v=DMARC1; p=none"

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

origin_domain_servers     = []
use_origin_domain_servers = false
