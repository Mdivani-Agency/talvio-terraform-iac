# Lambda execution roles. Serverless attaches them per function with
# `role: <arn from SSM>`; it creates no roles of its own for this service.
#   api         HTTP handler: tables, upload grants, enqueue, token counting. No model calls.
#   authorizer  token verification only: logs.
#   worker      queue consumers: tables, own buckets, Bedrock, Textract.
#   scheduler   dispatcher + reconciler: tables, queues incl. DLQs, bucket sweeps.

locals {
  quarantine_arn  = aws_s3_bucket.this["quarantine"].arn
  artifacts_arn   = aws_s3_bucket.this["artifacts"].arn
  work_queue_arns = [for r in local.releases : aws_sqs_queue.work[r].arn]
  work_dlq_arns   = [for r in local.releases : aws_sqs_queue.work_dlq[r].arn]

  bedrock_model_arns = flatten([
    for region in var.bedrock_permitted_regions : [
      for m in var.bedrock_foundation_model_ids :
      "arn:${local.partition}:bedrock:${region}::foundation-model/${m}"
    ]
  ])
  bedrock_profile_arns = [
    for p in var.bedrock_inference_profile_ids :
    "arn:${local.partition}:bedrock:${var.region}:${local.account_id}:inference-profile/${p}"
  ]
  bedrock_guardrail_arn = "arn:${local.partition}:bedrock:${var.region}:${local.account_id}:guardrail/*"

  role_names = {
    api        = "${local.prefix}-api-${local.suffix}"
    authorizer = "${local.prefix}-authorizer-${local.suffix}"
    worker     = "${local.prefix}-worker-${local.suffix}"
    scheduler  = "${local.prefix}-scheduler-${local.suffix}"
  }
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_iam_role" "this" {
  for_each = local.role_names

  name               = each.value
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

# --- shared statements -------------------------------------------------------

data "aws_iam_policy_document" "logs" {
  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:${local.partition}:logs:${var.region}:${local.account_id}:log-group:/aws/lambda/${var.lambda_service_name}-${var.environment}-*:*"]
  }
}

resource "aws_iam_role_policy" "logs" {
  for_each = local.role_names

  name   = "logs"
  role   = aws_iam_role.this[each.key].id
  policy = data.aws_iam_policy_document.logs.json
}

data "aws_iam_policy_document" "kms_use" {
  statement {
    sid       = "UseServiceKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [aws_kms_key.this.arn]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = [
        "s3.${var.region}.amazonaws.com",
        "sqs.${var.region}.amazonaws.com",
        "dynamodb.${var.region}.amazonaws.com",
      ]
    }
  }
}

data "aws_iam_policy_document" "metrics" {
  statement {
    sid       = "AppMetrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["Talvio/LLM"]
    }
  }
}

# --- api ---------------------------------------------------------------------

data "aws_iam_policy_document" "api" {
  source_policy_documents = [
    data.aws_iam_policy_document.kms_use.json,
    data.aws_iam_policy_document.metrics.json,
  ]

  statement {
    sid       = "Tables"
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:BatchGetItem", "dynamodb:Query", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:ConditionCheckItem"]
    resources = concat(local.table_arns, local.table_index_arns)
  }

  statement {
    sid       = "UploadGrants"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:AbortMultipartUpload", "s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${local.quarantine_arn}/pending/*"]
  }

  statement {
    sid       = "ReadResults"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${local.artifacts_arn}/results/*", "${local.artifacts_arn}/metadata/*"]
  }

  statement {
    sid       = "Enqueue"
    effect    = "Allow"
    actions   = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
    resources = local.work_queue_arns
  }

  # Preflight token counting only.
  statement {
    sid       = "CountTokens"
    effect    = "Allow"
    actions   = ["bedrock:CountTokens"]
    resources = concat(local.bedrock_model_arns, local.bedrock_profile_arns)
  }

  # Explicit so no later policy edit can give the API a model or OCR path.
  statement {
    sid       = "NoModelOrOcr"
    effect    = "Deny"
    actions   = ["bedrock:InvokeModel*", "bedrock:ApplyGuardrail", "textract:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "api" {
  name   = "api"
  role   = aws_iam_role.this["api"].id
  policy = data.aws_iam_policy_document.api.json
}

# --- worker ------------------------------------------------------------------

data "aws_iam_policy_document" "worker" {
  source_policy_documents = [
    data.aws_iam_policy_document.kms_use.json,
    data.aws_iam_policy_document.metrics.json,
  ]

  statement {
    sid       = "Tables"
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:BatchGetItem", "dynamodb:Query", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:ConditionCheckItem"]
    resources = concat(local.table_arns, local.table_index_arns)
  }

  statement {
    sid       = "QuarantineRead"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${local.quarantine_arn}/pending/*", "${local.quarantine_arn}/raw/*", "${local.quarantine_arn}/derivatives/*"]
  }

  statement {
    sid       = "QuarantinePromote"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:DeleteObjectVersion"]
    resources = ["${local.quarantine_arn}/raw/*", "${local.quarantine_arn}/derivatives/*", "${local.quarantine_arn}/pending/*"]
  }

  statement {
    sid       = "Artifacts"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject", "s3:DeleteObject", "s3:DeleteObjectVersion"]
    resources = ["${local.artifacts_arn}/results/*", "${local.artifacts_arn}/metadata/*"]
  }

  statement {
    sid       = "ConsumeAndRetry"
    effect    = "Allow"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
    resources = concat(local.work_queue_arns, [aws_sqs_queue.ocr.arn])
  }

  statement {
    sid       = "Requeue"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = local.work_queue_arns
  }

  statement {
    sid       = "Models"
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream", "bedrock:CountTokens"]
    resources = concat(local.bedrock_model_arns, local.bedrock_profile_arns)
  }

  statement {
    sid       = "Guardrail"
    effect    = "Allow"
    actions   = ["bedrock:ApplyGuardrail"]
    resources = [local.bedrock_guardrail_arn]
  }

  # Textract has no resource-level permissions for these actions.
  statement {
    sid       = "Ocr"
    effect    = "Allow"
    actions   = ["textract:StartDocumentTextDetection", "textract:GetDocumentTextDetection"]
    resources = ["*"]
  }

  statement {
    sid       = "PassOcrNotificationRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.textract.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["textract.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "worker" {
  name   = "worker"
  role   = aws_iam_role.this["worker"].id
  policy = data.aws_iam_policy_document.worker.json
}

# --- scheduler (dispatcher + reconciler) -------------------------------------

data "aws_iam_policy_document" "scheduler" {
  source_policy_documents = [
    data.aws_iam_policy_document.kms_use.json,
    data.aws_iam_policy_document.metrics.json,
  ]

  statement {
    sid       = "Tables"
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:BatchGetItem", "dynamodb:Query", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:ConditionCheckItem"]
    resources = concat(local.table_arns, local.table_index_arns)
  }

  statement {
    sid       = "QueuesAndDlqs"
    effect    = "Allow"
    actions   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
    resources = concat(local.work_queue_arns, local.work_dlq_arns, [aws_sqs_queue.ocr.arn, aws_sqs_queue.ocr_dlq.arn])
  }

  # Cleanup sweep for objects whose owner or job was tombstoned.
  statement {
    sid       = "SweepList"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:ListBucketVersions"]
    resources = [local.quarantine_arn, local.artifacts_arn]
  }

  statement {
    sid       = "SweepDelete"
    effect    = "Allow"
    actions   = ["s3:DeleteObject", "s3:DeleteObjectVersion"]
    resources = ["${local.quarantine_arn}/*", "${local.artifacts_arn}/*"]
  }
}

resource "aws_iam_role_policy" "scheduler" {
  name   = "scheduler"
  role   = aws_iam_role.this["scheduler"].id
  policy = data.aws_iam_policy_document.scheduler.json
}
