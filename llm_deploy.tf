# GitHub Actions deploy role for talvio-llm-service (MDI-213).
#
# Lives in the main root, so it is created by CI like every other resource and
# bootstrap/ stays a once-per-environment root (state bucket, OIDC provider,
# Terraform role). The OIDC provider is looked up, not created.
#
# Trust is limited to the repo's GitHub Environment for this stage
# (environment:dev in the dev account, environment:prod in prod), so a dev job
# cannot assume the prod role and branch rules live on the Environment. Ref
# subjects are intentionally not trusted. Both the classic and the immutable
# (org/repo id) subject forms are accepted, as in bootstrap/oidc.tf.

data "aws_caller_identity" "llm_deploy" {
  count = var.enable_platform && var.enable_llm ? 1 : 0
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.enable_platform && var.enable_llm ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  # Empty when LLM is disabled: the data source then has no instance and a null
  # would break the string interpolation in the policy below at plan time.
  llm_account_id = try(data.aws_caller_identity.llm_deploy[0].account_id, "")

  llm_subs = [
    for prefix in [
      "${var.github_org}/${var.llm_repo}",
      "${var.github_org}@${var.github_org_id}/${var.llm_repo}@${var.llm_repo_id}",
    ] : "repo:${prefix}:environment:${var.environment}"
  ]

  llm_stack      = "llm-service-${var.environment}"
  llm_role_arns  = "arn:aws:iam::${local.llm_account_id}:role/talvio-llm-*-${var.environment}"
  llm_deployment = "arn:aws:s3:::serverless-framework-deployments-${var.region}-*"

  # Scoped to this service's stack, functions, log groups and rules. The
  # service roles, tables, buckets and queues are Terraform-owned
  # (modules/llm), so the deployer only passes the roles and reads SSM; it
  # cannot create IAM roles, tables, queues or buckets.
  llm_deploy_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Stack"
        Effect = "Allow"
        Action = ["cloudformation:*"]
        Resource = [
          "arn:aws:cloudformation:${var.region}:${local.llm_account_id}:stack/${local.llm_stack}/*",
        ]
      },
      {
        Sid      = "StackDiscovery"
        Effect   = "Allow"
        Action   = ["cloudformation:ValidateTemplate", "cloudformation:ListStacks", "cloudformation:DescribeStacks"]
        Resource = "*"
      },
      {
        Sid      = "Functions"
        Effect   = "Allow"
        Action   = ["lambda:*"]
        Resource = "arn:aws:lambda:${var.region}:${local.llm_account_id}:function:llm-service-${var.environment}-*"
      },
      {
        Sid      = "EventSourceMappings"
        Effect   = "Allow"
        Action   = ["lambda:CreateEventSourceMapping", "lambda:UpdateEventSourceMapping", "lambda:DeleteEventSourceMapping", "lambda:GetEventSourceMapping", "lambda:ListEventSourceMappings", "lambda:ListFunctions"]
        Resource = "*"
      },
      {
        Sid      = "Api"
        Effect   = "Allow"
        Action   = ["apigateway:*"]
        Resource = "arn:aws:apigateway:${var.region}::/*"
      },
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = ["logs:*"]
        Resource = [
          "arn:aws:logs:${var.region}:${local.llm_account_id}:log-group:/aws/lambda/llm-service-${var.environment}-*",
          "arn:aws:logs:${var.region}:${local.llm_account_id}:log-group:/aws/lambda/llm-service-${var.environment}-*:*",
          "arn:aws:logs:${var.region}:${local.llm_account_id}:log-group:/aws/api-gateway/llm-service-${var.environment}*",
        ]
      },
      {
        Sid      = "LogDiscovery"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = "*"
      },
      {
        Sid      = "ScheduleEvents"
        Effect   = "Allow"
        Action   = ["events:*"]
        Resource = "arn:aws:events:${var.region}:${local.llm_account_id}:rule/${local.llm_stack}-*"
      },
      {
        Sid      = "DeploymentBucket"
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = [local.llm_deployment, "${local.llm_deployment}/*"]
      },
      {
        Sid      = "PassServiceRoles"
        Effect   = "Allow"
        Action   = ["iam:PassRole", "iam:GetRole"]
        Resource = local.llm_role_arns
      },
      {
        Sid    = "ReadConfiguration"
        Effect = "Allow"
        Action = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = [
          "arn:aws:ssm:${var.region}:${local.llm_account_id}:parameter/${var.environment}/*",
          "arn:aws:ssm:${var.region}:${local.llm_account_id}:parameter/serverless-framework/*",
        ]
      },
      {
        Sid      = "ServerlessDeploymentBucketParam"
        Effect   = "Allow"
        Action   = ["ssm:PutParameter"]
        Resource = "arn:aws:ssm:${var.region}:${local.llm_account_id}:parameter/serverless-framework/*"
      },
    ]
  })
}

module "llm_deploy" {
  count  = var.enable_platform && var.enable_llm ? 1 : 0
  source = "./modules/ci_oidc"

  name               = "talvio-gha-llm-deploy-${var.environment}"
  environment        = var.environment
  oidc_provider_arn  = data.aws_iam_openid_connect_provider.github[0].arn
  github_subs        = local.llm_subs
  inline_policy_json = local.llm_deploy_policy
  ssm_parameter_name = "/${var.environment}/ci/llm-deploy-role-arn"
}
