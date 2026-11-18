# Work queues (one per pipeline release) and OCR completion. Event source
# mappings, partial-batch-failure settings and batch size are Serverless-owned.

locals {
  visibility_timeout = var.worker_timeout_seconds * 6
  releases           = toset(var.pipeline_releases)
}

resource "aws_sqs_queue" "work_dlq" {
  for_each = local.releases

  name                              = "${local.prefix}-work-${each.key}-dlq-${local.suffix}"
  message_retention_seconds         = var.dlq_retention_seconds
  kms_master_key_id                 = aws_kms_key.this.arn
  kms_data_key_reuse_period_seconds = 300
  tags                              = local.tags
}

resource "aws_sqs_queue" "work" {
  for_each = local.releases

  name                              = "${local.prefix}-work-${each.key}-${local.suffix}"
  visibility_timeout_seconds        = local.visibility_timeout
  message_retention_seconds         = 345600 # 4 days; jobs carry a 10 minute deadline
  kms_master_key_id                 = aws_kms_key.this.arn
  kms_data_key_reuse_period_seconds = 300
  tags                              = local.tags

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.work_dlq[each.key].arn
    maxReceiveCount     = var.work_queue_max_receive_count
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "work_dlq" {
  for_each = local.releases

  queue_url = aws_sqs_queue.work_dlq[each.key].id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.work[each.key].arn]
  })
}

# Textract publishes OCR completion to SNS; the SQS subscription lives with
# the topic because both are Terraform resources. The consuming Lambda mapping
# stays in Serverless.
resource "aws_sns_topic" "ocr_completion" {
  name              = "${local.prefix}-ocr-completion-${local.suffix}"
  kms_master_key_id = aws_kms_key.this.arn
  tags              = local.tags
}

resource "aws_sqs_queue" "ocr_dlq" {
  name                              = "${local.prefix}-ocr-dlq-${local.suffix}"
  message_retention_seconds         = var.dlq_retention_seconds
  kms_master_key_id                 = aws_kms_key.this.arn
  kms_data_key_reuse_period_seconds = 300
  tags                              = local.tags
}

resource "aws_sqs_queue" "ocr" {
  name                              = "${local.prefix}-ocr-${local.suffix}"
  visibility_timeout_seconds        = local.visibility_timeout
  message_retention_seconds         = 345600
  kms_master_key_id                 = aws_kms_key.this.arn
  kms_data_key_reuse_period_seconds = 300
  tags                              = local.tags

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ocr_dlq.arn
    maxReceiveCount     = var.work_queue_max_receive_count
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "ocr_dlq" {
  queue_url = aws_sqs_queue.ocr_dlq.id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.ocr.arn]
  })
}

data "aws_iam_policy_document" "ocr_queue" {
  statement {
    sid       = "AllowOcrTopic"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.ocr.arn]
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.ocr_completion.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "ocr" {
  queue_url = aws_sqs_queue.ocr.id
  policy    = data.aws_iam_policy_document.ocr_queue.json
}

resource "aws_sns_topic_subscription" "ocr" {
  topic_arn = aws_sns_topic.ocr_completion.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.ocr.arn

  depends_on = [aws_sqs_queue_policy.ocr]
}

# Textract assumes this role to publish completion to SNS. Passed by the
# worker on StartDocumentTextDetection (NotificationChannel).
resource "aws_iam_role" "textract" {
  name = "AmazonTextract-${local.prefix}-${local.suffix}"
  path = "/service-role/"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "textract.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account_id }
      }
    }]
  })
}

resource "aws_iam_role_policy" "textract" {
  name = "publish-ocr-completion"
  role = aws_iam_role.textract.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.ocr_completion.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey*"]
        Resource = aws_kms_key.this.arn
      },
    ]
  })
}
