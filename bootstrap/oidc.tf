# GitHub Actions OIDC lives here (chicken-and-egg with the main state).
# Apply this root locally with account-admin credentials, then store the
# terraform role ARN as DEV_AWS_ROLE_ARN / PROD_AWS_ROLE_ARN on GitHub.

locals {
  github_oidc_url = "https://token.actions.githubusercontent.com"

  # GitHub Actions OIDC: org repos created after 15 Jul 2026 emit immutable
  #   repo:<org>@<org_id>/<repo>@<repo_id>:<suffix>
  # Older tokens (and some job types) still use classic
  #   repo:<org>/<repo>:<suffix>
  # Trust both so bootstrap apply cannot wipe a console patch, and so
  # prod first-apply works without a manual trust edit.
  oidc_claim_prefixes = {
    for name in toset([var.terraform_repo, var.media_repo, var.email_repo]) : name => [
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
