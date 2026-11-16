# Alarms on the service's own metrics (MDI-223). The service writes them as
# CloudWatch embedded metric format lines in its logs, namespace Talvio/LLM,
# each with a Stage dimension equal to var.environment (see the service's
# README and docs/runbook.md, which says what to do for each alarm).

locals {
  app_namespace = "Talvio/LLM"
  stage         = { Stage = var.environment }
}

# Metered spend over a rolling 24 hours against the account's daily ceiling.
# The service refuses new paid jobs at 100% (per UTC day); this warns first.
resource "aws_cloudwatch_metric_alarm" "spend" {
  alarm_name          = "${local.prefix}-spend-${floor(var.spend_alarm_fraction * 100)}pct-${local.suffix}"
  alarm_description   = "Metered LLM spend over the last 24 hours reached ${floor(var.spend_alarm_fraction * 100)}% of the daily ceiling (USD ${var.account_daily_ceiling_micro_usd / 1000000})."
  namespace           = local.app_namespace
  metric_name         = "JobCostMicroUsd"
  dimensions          = local.stage
  statistic           = "Sum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = floor(var.account_daily_ceiling_micro_usd * var.spend_alarm_fraction)
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "ceiling_reached" {
  alarm_name          = "${local.prefix}-ceiling-reached-${local.suffix}"
  alarm_description   = "Admission refused a job because the account's daily spend ceiling was reached."
  namespace           = local.app_namespace
  metric_name         = "QuotaRejected"
  dimensions          = merge(local.stage, { Kind = "account_ceiling" })
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}

# Jobs the reconciler ended at their deadline: work that got stuck.
resource "aws_cloudwatch_metric_alarm" "stuck_jobs" {
  alarm_name          = "${local.prefix}-stuck-jobs-${local.suffix}"
  alarm_description   = "The reconciler expired jobs at their deadline."
  namespace           = local.app_namespace
  metric_name         = "ReconcileExpired"
  dimensions          = local.stage
  statistic           = "Sum"
  period              = 900
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "reconcile_failed" {
  alarm_name          = "${local.prefix}-reconcile-failed-${local.suffix}"
  alarm_description   = "The reconciler could not process a job."
  namespace           = local.app_namespace
  metric_name         = "ReconcileFailed"
  dimensions          = local.stage
  statistic           = "Sum"
  period              = 900
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}

# A model answer that failed the contract check before publishing: a prompt,
# model or schema regression. Should never happen.
resource "aws_cloudwatch_metric_alarm" "result_invalid" {
  alarm_name          = "${local.prefix}-result-invalid-${local.suffix}"
  alarm_description   = "A result failed its contract check and was not published."
  namespace           = local.app_namespace
  metric_name         = "ResultInvalid"
  dimensions          = local.stage
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}

resource "aws_cloudwatch_metric_alarm" "job_failure_rate" {
  alarm_name          = "${local.prefix}-job-failure-rate-${local.suffix}"
  alarm_description   = "More than ${floor(var.job_failure_rate_alarm * 100)}% of finished jobs failed over 15 minutes."
  evaluation_periods  = 1
  threshold           = var.job_failure_rate_alarm
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.tags

  metric_query {
    id          = "rate"
    expression  = "IF(finished >= 5, failed / finished, 0)"
    label       = "Failed share of finished jobs"
    return_data = true
  }

  metric_query {
    id = "failed"
    metric {
      namespace   = local.app_namespace
      metric_name = "JobFinished"
      dimensions  = merge(local.stage, { Outcome = "failed" })
      stat        = "Sum"
      period      = 900
    }
  }

  metric_query {
    id = "finished"
    metric {
      namespace   = local.app_namespace
      metric_name = "JobFinished"
      dimensions  = local.stage
      stat        = "Sum"
      period      = 900
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "job_cost_p95" {
  alarm_name          = "${local.prefix}-job-cost-p95-${local.suffix}"
  alarm_description   = "p95 cost per job over an hour is above USD ${var.job_cost_p95_alarm_micro_usd / 1000000}."
  namespace           = local.app_namespace
  metric_name         = "JobCostMicroUsd"
  dimensions          = local.stage
  extended_statistic  = "p95"
  period              = 3600
  evaluation_periods  = 1
  threshold           = var.job_cost_p95_alarm_micro_usd
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
  tags                = local.tags
}
