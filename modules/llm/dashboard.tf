# Operations dashboard (MDI-223): job outcomes, latency, cost and tokens per
# operation, quota refusals, reconciler results, queues and DLQs. Per-operation
# series come from SEARCH, so a new operation shows up without a change here.

locals {
  dashboard_search = {
    for name, spec in {
      finished = ["Operation,Outcome", "JobFinished", "Sum"]
      duration = ["Operation", "JobDurationMs", "p95"]
      cost     = ["Operation", "JobCostMicroUsd", "p95"]
      input    = ["Operation", "ModelInputTokens", "Sum"]
      output   = ["Operation", "ModelOutputTokens", "Sum"]
      quota    = ["Kind", "QuotaRejected", "Sum"]
      blocked  = ["Operation", "GuardrailBlocked", "Sum"]
      invalid  = ["Operation", "ResultInvalid", "Sum"]
      retried  = ["Operation", "JobRetried", "Sum"]
    } :
    name => "SEARCH('{${local.app_namespace},Stage,${spec[0]}} MetricName=\"${spec[1]}\" Stage=\"${var.environment}\"', '${spec[2]}', 300)"
  }

  dashboard_widget = {
    for name, def in {
      finished = { title = "Jobs finished by operation and outcome", search = "finished", y = 0, x = 0 }
      duration = { title = "p95 job duration (ms)", search = "duration", y = 0, x = 12 }
      cost     = { title = "p95 job cost (micro-USD; target 40,000, cap 50,000)", search = "cost", y = 6, x = 0 }
      quota    = { title = "Admission refused by limit", search = "quota", y = 12, x = 0 }
      retried  = { title = "Step retries", search = "retried", y = 12, x = 12 }
      input    = { title = "Model input tokens", search = "input", y = 18, x = 0 }
      output   = { title = "Model output tokens", search = "output", y = 18, x = 12 }
      blocked  = { title = "Input guardrail blocks", search = "blocked", y = 24, x = 0 }
      invalid  = { title = "Results that failed the contract check", search = "invalid", y = 24, x = 12 }
    } :
    name => {
      type   = "metric"
      x      = def.x
      y      = def.y
      width  = 12
      height = 6
      properties = {
        title   = def.title
        region  = var.region
        view    = "timeSeries"
        stacked = false
        period  = 300
        metrics = [[{ expression = local.dashboard_search[def.search], id = "s" }]]
      }
    }
  }
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${local.prefix}-${local.suffix}"

  dashboard_body = jsonencode({
    widgets = concat(
      values(local.dashboard_widget),
      [
        {
          type   = "metric"
          x      = 12
          y      = 6
          width  = 12
          height = 6
          properties = {
            title  = "Spend over 24 hours (micro-USD; alarm at ${floor(var.account_daily_ceiling_micro_usd * var.spend_alarm_fraction)}, ceiling ${var.account_daily_ceiling_micro_usd})"
            region = var.region
            view   = "singleValue"
            # Always the last 24 hours, whatever range the dashboard shows.
            start                = "-PT24H"
            setPeriodToTimeRange = true
            period               = 86400
            stat                 = "Sum"
            metrics              = [[local.app_namespace, "JobCostMicroUsd", "Stage", var.environment, { label = "Spent (24 h)" }]]
          }
        },
        {
          type   = "metric"
          x      = 0
          y      = 30
          width  = 12
          height = 6
          properties = {
            title  = "Reconciler: due, expired (stuck), requeued, failed"
            region = var.region
            view   = "timeSeries"
            period = 300
            stat   = "Sum"
            metrics = [
              for name in ["ReconcileDue", "ReconcileExpired", "ReconcileRequeued", "ReconcileFailed"] :
              [local.app_namespace, name, "Stage", var.environment]
            ]
          }
        },
        {
          type   = "metric"
          x      = 12
          y      = 30
          width  = 12
          height = 6
          properties = {
            title  = "Oldest message age (s) and DLQ depth"
            region = var.region
            view   = "timeSeries"
            period = 60
            stat   = "Maximum"
            metrics = concat(
              [for key, queue in local.live_queues : ["AWS/SQS", "ApproximateAgeOfOldestMessage", "QueueName", queue, { label = "${key} age" }]],
              [for key, queue in local.dlqs : ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", queue, { label = "${key} DLQ", yAxis = "right" }]],
            )
          }
        },
      ],
    )
  })
}
