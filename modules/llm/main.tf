# LLM orchestration service shared resources (MDI-213).
#
# Ownership: Terraform owns every stateful or shared resource here (KMS,
# S3, SQS/SNS, IAM roles, alarms, configuration). DynamoDB tables come from
# modules/dynamodb at the root. Serverless owns functions, HTTP routes, the
# authorizer, Lambda event source mappings and schedule events, and reads
# everything below by SSM path.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  prefix     = "talvio-llm"
  suffix     = var.environment

  tags = merge(var.tags, {
    Environment = var.environment
    Project     = "talvio-llm"
    ManagedBy   = "terraform"
  })

  table_arns = [
    for k in ["jobs", "sessions", "quotas", "outbox"] :
    "arn:${local.partition}:dynamodb:${var.region}:${local.account_id}:table/${var.table_names[k]}"
  ]
  table_index_arns = [for arn in local.table_arns : "${arn}/index/*"]
}

# One key for queues, topics, buckets and (via the table definition) any
# future encrypted store. Customer managed so access is auditable and the
# API/worker roles can be scoped to it.
resource "aws_kms_key" "this" {
  description             = "Talvio LLM service (${var.environment})"
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_protection ? 30 : 7
  policy                  = data.aws_iam_policy_document.kms.json
  tags                    = local.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/${local.prefix}-${local.suffix}"
  target_key_id = aws_kms_key.this.key_id
}

data "aws_iam_policy_document" "kms" {
  statement {
    sid       = "AccountAdministration"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  # SNS delivers to the encrypted OCR queue; CloudWatch alarms publish to the
  # encrypted alarm topic. IAM principals get access through their own policies.
  statement {
    sid       = "ServicesInThisAccount"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com", "cloudwatch.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}
