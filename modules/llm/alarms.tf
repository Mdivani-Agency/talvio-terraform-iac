# Queue-level alarms only. Accounting overrun, stuck leases, failure rate,
# p95 cost and account exposure need the application's own metrics
# (namespace Talvio/LLM, which the roles may write) and are added alongside
# the code that emits them (MDI-214/215/224).

resource "aws_sns_topic" "alarms" {
  name              = "${local.prefix}-alarms-${local.suffix}"
  kms_master_key_id = aws_kms_key.this.arn
  tags              = local.tags
}

resource "aws_sns_topic_subscription" "alarm_email" {
  for_each = toset(var.alarm_email_addresses)

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = each.value
}

locals {
  dlqs = merge(
    { for r in local.releases : "work-${r}" => aws_sqs_queue.work_dlq[r].name },
    { ocr = aws_sqs_queue.ocr_dlq.name },
  )
  live_queues = merge(
    { for r in local.releases : "work-${r}" => aws_sqs_queue.work[r].name },
    { ocr = aws_sqs_queue.ocr.name },
  )
}

resource "aws_cloudwatch_metric_alarm" "dlq_arrivals" {
  for_each = local.dlqs

  alarm_name          = "${local.prefix}-${each.key}-dlq-arrivals-${local.suffix}"
  alarm_description   = "A message reached the ${each.key} dead-letter queue."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = each.value }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "queue_age" {
  for_each = local.live_queues

  alarm_name          = "${local.prefix}-${each.key}-queue-age-${local.suffix}"
  alarm_description   = "Oldest ${each.key} message is older than ${var.queue_age_alarm_seconds}s."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  dimensions          = { QueueName = each.value }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = var.queue_age_alarm_seconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}
