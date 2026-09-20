# Greenfield names — Notion "Naming (dev)". No legacy cohub.click / ARNs / buckets.
environment        = "dev"
region             = "us-west-1"
enable_platform    = true
create_hosted_zone = true
root_domain        = "dev.talvio.co"
hosted_zone_id     = "" # created by modules/dns

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
