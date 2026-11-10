variable "environment" {
  type        = string
  description = "Stage name (dev or prod)."
}

variable "region" {
  type        = string
  description = "Application region. Lambda, SQS, SNS, S3, KMS and Textract all live here."
}

variable "table_names" {
  type        = map(string)
  description = "Names of the Terraform-owned DynamoDB tables (modules/dynamodb), keyed jobs, sessions, quotas, outbox. Used to scope IAM; the tables themselves are not created here."

  validation {
    condition     = alltrue([for k in ["jobs", "sessions", "quotas", "outbox"] : contains(keys(var.table_names), k)])
    error_message = "table_names must define jobs, sessions, quotas and outbox."
  }
}

variable "pipeline_releases" {
  type        = list(string)
  description = "Pipeline release ids. Each gets its own work queue and DLQ so in-flight jobs finish on the release that admitted them."
  default     = ["v1"]

  validation {
    condition     = length(var.pipeline_releases) > 0 && alltrue([for r in var.pipeline_releases : can(regex("^[a-z0-9]+$", r))])
    error_message = "pipeline_releases must be a non-empty list of lowercase alphanumeric ids."
  }
}

variable "worker_timeout_seconds" {
  type        = number
  description = "Worker Lambda timeout. Queue visibility timeout is six times this (AWS guidance for SQS event sources)."
  default     = 300
}

variable "work_queue_max_receive_count" {
  type        = number
  description = "Receives before a work message moves to its DLQ."
  default     = 3
}

variable "dlq_retention_seconds" {
  type    = number
  default = 1209600 # 14 days, the SQS maximum
}

variable "bedrock_foundation_model_ids" {
  type        = list(string)
  description = "Foundation models the worker may invoke (and the API may count tokens for)."
  default = [
    "anthropic.claude-haiku-4-5-20251001-v1:0",
    "amazon.nova-2-lite-v1:0",
  ]
}

variable "bedrock_inference_profile_ids" {
  type        = list(string)
  description = "US geographic inference profiles the worker may use. Global profiles are not permitted."
  default = [
    "us.anthropic.claude-haiku-4-5-20251001-v1:0",
    "us.amazon.nova-2-lite-v1:0",
  ]

  validation {
    condition     = alltrue([for p in var.bedrock_inference_profile_ids : !startswith(p, "global.")])
    error_message = "Global inference profiles are disabled; use a US geographic profile."
  }
}

variable "bedrock_permitted_regions" {
  type        = list(string)
  description = "Regions the US geographic profile may execute in. Foundation-model ARNs are granted for each. Separate from var.region."
  default     = ["us-east-1", "us-east-2", "us-west-1", "us-west-2"]
}

variable "bedrock_default_inference_profile_id" {
  type        = string
  description = "Profile the production pipeline uses. Published to SSM."
  default     = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "pending_upload_expiry_days" {
  type        = number
  description = "Quarantine pending/ objects (uploads never accepted)."
  default     = 1
}

variable "raw_expiry_days" {
  type        = number
  description = "Quarantine raw/ and derivatives/ objects, and artifact results/ (unaccepted results)."
  default     = 7
}

variable "metadata_expiry_days" {
  type        = number
  description = "Content-free artifact metadata/."
  default     = 30
}

variable "deletion_protection" {
  type        = bool
  description = "Prod safety: deny s3:DeleteBucket on the buckets, keep the KMS key for 30 days after deletion is scheduled."
  default     = false
}

variable "alarm_email_addresses" {
  type        = list(string)
  description = "Optional email subscriptions for the alarm topic. Each recipient must confirm."
  default     = []
}

variable "queue_age_alarm_seconds" {
  type        = number
  description = "Alarm when the oldest message in a work or OCR queue is older than this."
  default     = 60
}

variable "dispatcher_schedule" {
  type        = string
  description = "Cadence of the outbox dispatcher. Serverless wires the schedule event from this SSM value."
  default     = "rate(1 minute)"
}

variable "reconciler_schedule" {
  type        = string
  description = "Cadence of the reconciler. Serverless wires the schedule event from this SSM value."
  default     = "rate(5 minutes)"
}

variable "lambda_service_name" {
  type        = string
  description = "Serverless service name. Scopes log permissions to /aws/lambda/<service>-<stage>-*."
  default     = "llm-service"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "upload_allowed_origins" {
  type        = list(string)
  description = "Browser origins allowed to PUT to a presigned upload URL (CORS on the quarantine bucket). Empty means no CORS."
  default     = []

  validation {
    condition     = alltrue([for o in var.upload_allowed_origins : can(regex("^https?://[^/]+$", o))])
    error_message = "Origins are scheme://host[:port] with no path."
  }
}
