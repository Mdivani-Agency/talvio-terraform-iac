# LLM orchestration service shared resources (MDI-213, epic MDI-181).
#
# Terraform owns every stateful resource: the DynamoDB tables (declared in
# the tfvars `dynamo_db_tables` map and created by modules/dynamodb), the
# private buckets, queues, topic, KMS key, alarms, and the Lambda roles
# (modules/llm). talvio-llm-service reads their names and ARNs from SSM:
#   /<env>/dynamodb/llm-{jobs,sessions,quotas,outbox}
#   /<env>/s3/llm-{quarantine,artifacts}
#   /<env>/llm/*
# Serverless owns functions, routes, the authorizer, event source mappings
# and schedule events. Nothing here touches the public media CDN or Supabase.

locals {
  llm_table_names = {
    for k in ["jobs", "sessions", "quotas", "outbox"] : k => "talvio-llm-${k}-${var.environment}"
  }

  llm_module = var.enable_platform && var.enable_llm ? module.llm[0] : null

  llm_ssm = local.llm_module == null ? {} : merge(
    { for k, name in local.llm_table_names : "llm-${k}" => {
      value       = name
      type        = "String"
      prefix      = "dynamodb"
      description = "LLM ${k} DynamoDB table name"
    } },
    { for k, name in local.llm_module.bucket_names : "llm-${k}" => {
      value       = name
      type        = "String"
      prefix      = "s3"
      description = "LLM ${k} S3 bucket name (private)"
    } },
    { for k, p in local.llm_module.ssm_parameters : k => {
      value       = p.value
      type        = "String"
      prefix      = "llm"
      description = p.description
    } },
  )
}

module "llm" {
  count  = var.enable_platform && var.enable_llm ? 1 : 0
  source = "./modules/llm"

  environment                          = var.environment
  region                               = var.region
  table_names                          = local.llm_table_names
  pipeline_releases                    = var.llm_pipeline_releases
  worker_timeout_seconds               = var.llm_worker_timeout_seconds
  bedrock_foundation_model_ids         = var.llm_bedrock_foundation_model_ids
  bedrock_inference_profile_ids        = var.llm_bedrock_inference_profile_ids
  bedrock_permitted_regions            = var.llm_bedrock_permitted_regions
  bedrock_default_inference_profile_id = var.llm_bedrock_default_inference_profile_id
  deletion_protection                  = var.environment == "prod"
  alarm_email_addresses                = var.llm_alarm_email_addresses
  upload_allowed_origins               = var.llm_upload_allowed_origins
  dispatcher_schedule                  = var.llm_dispatcher_schedule
  reconciler_schedule                  = var.llm_reconciler_schedule

  tags = {
    Environment = var.environment
    Project     = "talvio"
  }
}

# The IAM scoping in modules/llm is by table name, so the tfvars tables must
# exist under exactly those names (and keep PITR / deletion protection on prod).
check "llm_tables_declared" {
  assert {
    condition = !(var.enable_platform && var.enable_llm) || alltrue([
      for name in values(local.llm_table_names) : contains(keys(var.dynamo_db_tables), name)
    ])
    error_message = "dynamo_db_tables must declare talvio-llm-{jobs,sessions,quotas,outbox}-<env> when enable_llm is true."
  }
}
