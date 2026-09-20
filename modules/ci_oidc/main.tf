data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "GitHubOidc"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_subs
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "github-actions-oidc"
  })
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  count = var.inline_policy_json != "" ? 1 : 0

  name   = "${var.name}-inline"
  role   = aws_iam_role.this.id
  policy = var.inline_policy_json
}

resource "aws_ssm_parameter" "role_arn" {
  count = var.ssm_parameter_name != "" ? 1 : 0

  name        = var.ssm_parameter_name
  type        = "String"
  value       = aws_iam_role.this.arn
  description = "GitHub Actions deploy role ARN for ${var.environment}"
  tags = merge(var.tags, {
    Environment = var.environment
  })
}
