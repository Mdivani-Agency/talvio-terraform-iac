# GitHub Actions OIDC lives here (chicken-and-egg with the main state).
# Apply this root locally with account-admin credentials, then store the
# terraform role ARN as DEV_AWS_ROLE_ARN / PROD_AWS_ROLE_ARN on GitHub.

locals {
  github_oidc_url = "https://token.actions.githubusercontent.com"

  terraform_subs = var.environment == "prod" ? [
    "repo:${var.github_org}/${var.terraform_repo}:ref:refs/heads/main",
    "repo:${var.github_org}/${var.terraform_repo}:environment:prod",
    ] : [
    "repo:${var.github_org}/${var.terraform_repo}:pull_request",
    "repo:${var.github_org}/${var.terraform_repo}:ref:refs/heads/development",
    "repo:${var.github_org}/${var.terraform_repo}:environment:dev",
  ]

  # media-service deploys from `development`; email-service from `main`.
  # Environment subjects cover GitHub Environment protection on those repos.
  service_subs = [
    "repo:${var.github_org}/${var.media_repo}:ref:refs/heads/development",
    "repo:${var.github_org}/${var.media_repo}:ref:refs/heads/main",
    "repo:${var.github_org}/${var.media_repo}:environment:${var.environment}",
    "repo:${var.github_org}/${var.email_repo}:ref:refs/heads/main",
    "repo:${var.github_org}/${var.email_repo}:environment:${var.environment}",
  ]

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
