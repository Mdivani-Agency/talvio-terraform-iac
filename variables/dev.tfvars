# Greenfield names from Notion "Naming (dev)". Modules are not wired yet (MDI-180).
environment = "dev"
region      = "us-west-1"

root_domain    = "dev.talvio.co"
hosted_zone_id = "" # created in MDI-180 (new zone in the dedicated dev account)

root_domains = [
  {
    domain     = "dev.talvio.co"
    subdomains = ["www.dev.talvio.co", "api.dev.talvio.co", "media.dev.talvio.co"]
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

# Map key is both the DynamoDB table name and the SSM suffix (`/${env}/dynamodb/<key>`).
# Media-service reads /${stage}/dynamodb/media, so the key stays `media`.
# Physical name talvio-media-dev needs a module change in MDI-180 if we want both.
dynamo_db_tables = {
  media = {
    hash_key = "key"

    attributes = {
      key    = "S"
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
      acm_certificate_arn = "" # filled from module.ssl in MDI-180
      hosted_zone_id      = "" # filled after the new zone exists
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

ses_templates = {
  magic_link = {
    name      = "magic_link"
    subject   = "Talvio Auth Request"
    body_file = "magic_link.html"
  }
}

origin_domain_servers     = []
use_origin_domain_servers = false

parameters = {
  hosted_zone_id = {
    value  = ""
    prefix = "route-53"
  }
  ses_from_email = {
    value  = "no-reply@dev.talvio.co"
    prefix = "ses"
  }
  ses_domain = {
    value  = "dev.talvio.co"
    prefix = "ses"
  }
}
