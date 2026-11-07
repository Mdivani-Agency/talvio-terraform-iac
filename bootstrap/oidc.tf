# GitHub Actions OIDC lives here (chicken-and-egg with the main state).
# Apply this root locally with account-admin credentials, then store the
# terraform role ARN as DEV_AWS_ROLE_ARN / PROD_AWS_ROLE_ARN on GitHub.

data "aws_caller_identity" "current" {}

locals {
  github_oidc_url = "https://token.actions.githubusercontent.com"

  # GitHub Actions OIDC: org repos created after 15 Jul 2026 emit immutable
  #   repo:<org>@<org_id>/<repo>@<repo_id>:<suffix>
  # Older tokens (and some job types) still use classic
  #   repo:<org>/<repo>:<suffix>
  # Trust both so bootstrap apply cannot wipe a console patch, and so
  # prod first-apply works without a manual trust edit.
  oidc_claim_prefixes = {
    for name in toset([var.terraform_repo, var.media_repo, var.email_repo, var.llm_repo]) : name => [
      "${var.github_org}/${name}",
      "${var.github_org}@${var.github_org_id}/${name}@${var.github_repo_ids[name]}",
    ]
  }

  terraform_suffixes = var.environment == "prod" ? [
    "ref:refs/heads/main",
    "environment:prod",
    ] : [
    "pull_request",
    "ref:refs/heads/development",
    "environment:dev",
  ]

  # media-service and email-service both deploy from development (dev) and
  # main (prod). Environment subjects cover GitHub Environment protection.
  service_suffixes = [
    "ref:refs/heads/development",
    "ref:refs/heads/main",
    "environment:${var.environment}",
  ]

  terraform_subs = flatten([
    for suffix in local.terraform_suffixes : [
      for prefix in local.oidc_claim_prefixes[var.terraform_repo] : "repo:${prefix}:${suffix}"
    ]
  ])

  service_subs = flatten([
    for repo in [var.media_repo, var.email_repo] : [
      for suffix in local.service_suffixes : [
        for prefix in local.oidc_claim_prefixes[repo] : "repo:${prefix}:${suffix}"
      ]
    ]
  ])

  # talvio-llm-service deploys only through its GitHub Environment for this
  # stage (environment:dev in the dev account, environment:prod in prod), so
  # a dev token cannot assume the prod role and branch rules live on the
  # Environment. Ref subjects are intentionally not trusted.
  llm_subs = flatten([
    for prefix in local.oidc_claim_prefixes[var.llm_repo] : "repo:${prefix}:environment:${var.environment}"
  ])

  llm_stack      = "llm-service-${var.environment}"
  llm_role_arns  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/talvio-llm-*-${var.environment}"
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
          "arn:aws:cloudformation:${var.region}:${data.aws_caller_identity.current.account_id}:stack/${local.llm_stack}/*",
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
        Resource = "arn:aws:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:llm-service-${var.environment}-*"
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
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/llm-service-${var.environment}-*",
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/llm-service-${var.environment}-*:*",
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/api-gateway/llm-service-${var.environment}*",
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
        Resource = "arn:aws:events:${var.region}:${data.aws_caller_identity.current.account_id}:rule/${local.llm_stack}-*"
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
          "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.environment}/*",
          "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/serverless-framework/*",
        ]
      },
      {
        Sid      = "ServerlessDeploymentBucketParam"
        Effect   = "Allow"
        Action   = ["ssm:PutParameter"]
        Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/serverless-framework/*"
      },
    ]
  })

  serverless_deploy_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ServerlessDeploy"
        Effect = "Allow"
        Action = [
          "cloudformation:*",
          "lambda:*",
          "apigateway:*",
          "s3:*",
          "logs:*",
          "events:*",
          "iam:PassRole",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListPolicyVersions",
          "iam:ListInstanceProfilesForRole",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "acm:RequestCertificate",
          "acm:DeleteCertificate",
          "acm:AddTagsToCertificate",
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName",
          "route53:GetHostedZone",
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          "cloudfront:CreateInvalidation",
          "dynamodb:*",
        ]
        Resource = "*"
      },
      {
        # Serverless v4 keeps the shared deployment bucket name in SSM and
        # rewrites it when that bucket is missing (new stacks use the shared bucket).
        Sid      = "ServerlessDeploymentBucketParam"
        Effect   = "Allow"
        Action   = ["ssm:PutParameter"]
        Resource = "arn:aws:ssm:*:*:parameter/serverless-framework/*"
      },
    ]
  })
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = local.github_oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.github_oidc_thumbprints

  tags = {
    Name        = "github-actions"
    Environment = var.environment
    Project     = "talvio"
  }
}

module "terraform_role" {
  source = "../modules/ci_oidc"

  name              = "talvio-gha-terraform-${var.environment}"
  environment       = var.environment
  oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
  github_subs       = local.terraform_subs
  # Broad on purpose: this role applies the main root (MDI-180+). Tighten later.
  managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}

module "service_deploy" {
  source = "../modules/ci_oidc"

  name               = "talvio-gha-deploy-${var.environment}"
  environment        = var.environment
  oidc_provider_arn  = aws_iam_openid_connect_provider.github.arn
  github_subs        = local.service_subs
  inline_policy_json = local.serverless_deploy_policy
  ssm_parameter_name = "/${var.environment}/ci/deploy-role-arn"
}

# talvio-llm-service gets its own role, separate from the media/email one:
# narrower policy, and trust limited to this stage's GitHub Environment.
module "llm_deploy" {
  source = "../modules/ci_oidc"

  name               = "talvio-gha-llm-deploy-${var.environment}"
  environment        = var.environment
  oidc_provider_arn  = aws_iam_openid_connect_provider.github.arn
  github_subs        = local.llm_subs
  inline_policy_json = local.llm_deploy_policy
  ssm_parameter_name = "/${var.environment}/ci/llm-deploy-role-arn"
}
