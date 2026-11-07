output "kms_key_arn" {
  value = aws_kms_key.this.arn
}

output "bucket_names" {
  value = { for k, b in aws_s3_bucket.this : k => b.id }
}

output "bucket_arns" {
  value = { for k, b in aws_s3_bucket.this : k => b.arn }
}

output "work_queue_urls" {
  value = { for r, q in aws_sqs_queue.work : r => q.id }
}

output "work_queue_arns" {
  value = { for r, q in aws_sqs_queue.work : r => q.arn }
}

output "work_dlq_arns" {
  value = { for r, q in aws_sqs_queue.work_dlq : r => q.arn }
}

output "ocr_queue_url" {
  value = aws_sqs_queue.ocr.id
}

output "ocr_queue_arn" {
  value = aws_sqs_queue.ocr.arn
}

output "ocr_dlq_arn" {
  value = aws_sqs_queue.ocr_dlq.arn
}

output "ocr_topic_arn" {
  value = aws_sns_topic.ocr_completion.arn
}

output "textract_role_arn" {
  value = aws_iam_role.textract.arn
}

output "alarm_topic_arn" {
  value = aws_sns_topic.alarms.arn
}

output "role_arns" {
  value = { for k, r in aws_iam_role.this : k => r.arn }
}

output "ssm_parameters" {
  description = "Values for the root SSM module, keyed by name under /<env>/llm/. Table and bucket aliases live in the root."
  value = merge(
    {
      "kms-key-arn"                  = { value = aws_kms_key.this.arn, description = "LLM KMS key ARN" }
      "ocr-queue-url"                = { value = aws_sqs_queue.ocr.id, description = "OCR completion queue URL" }
      "ocr-queue-arn"                = { value = aws_sqs_queue.ocr.arn, description = "OCR completion queue ARN" }
      "ocr-dlq-arn"                  = { value = aws_sqs_queue.ocr_dlq.arn, description = "OCR completion DLQ ARN" }
      "ocr-topic-arn"                = { value = aws_sns_topic.ocr_completion.arn, description = "Textract completion SNS topic ARN" }
      "textract-role-arn"            = { value = aws_iam_role.textract.arn, description = "Role Textract assumes to publish completion" }
      "alarm-topic-arn"              = { value = aws_sns_topic.alarms.arn, description = "LLM alarm topic ARN" }
      "api-role-arn"                 = { value = aws_iam_role.this["api"].arn, description = "API Lambda role" }
      "authorizer-role-arn"          = { value = aws_iam_role.this["authorizer"].arn, description = "Authorizer Lambda role" }
      "worker-role-arn"              = { value = aws_iam_role.this["worker"].arn, description = "Worker Lambda role" }
      "scheduler-role-arn"           = { value = aws_iam_role.this["scheduler"].arn, description = "Dispatcher and reconciler Lambda role" }
      "dispatcher-schedule"          = { value = var.dispatcher_schedule, description = "Outbox dispatcher cadence" }
      "reconciler-schedule"          = { value = var.reconciler_schedule, description = "Reconciler cadence" }
      "pipeline-releases"            = { value = join(",", var.pipeline_releases), description = "Pipeline release ids with a work queue" }
      "bedrock-region"               = { value = var.region, description = "Application and Bedrock source region" }
      "bedrock-permitted-regions"    = { value = join(",", var.bedrock_permitted_regions), description = "Regions the US inference profile may execute in" }
      "bedrock-inference-profile-id" = { value = var.bedrock_default_inference_profile_id, description = "Production inference profile" }
    },
    { for r, q in aws_sqs_queue.work : "work-queue-url-${r}" => { value = q.id, description = "Work queue URL, release ${r}" } },
    { for r, q in aws_sqs_queue.work : "work-queue-arn-${r}" => { value = q.arn, description = "Work queue ARN, release ${r}" } },
    { for r, q in aws_sqs_queue.work_dlq : "work-dlq-arn-${r}" => { value = q.arn, description = "Work DLQ ARN, release ${r}" } },
  )
}
