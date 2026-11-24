data "aws_caller_identity" "current" {}

data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  state_object_arn = "arn:aws:s3:::${var.state_bucket_name}/${var.state_key}"
  state_lock_arn   = "${local.state_object_arn}.tflock"
  role_path        = "/portfolio-tests/"
  boundary_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/portfolio-tests/portfolio-boundary"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_actions.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_subject_plan]
    }
  }
}

data "aws_iam_policy_document" "apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_subject_apply]
    }
  }
}

resource "aws_iam_role" "plan" {
  name                 = "portfolio-gh-plan"
  path                 = local.role_path
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role" "apply" {
  name                 = "portfolio-gh-apply"
  path                 = local.role_path
  assume_role_policy   = data.aws_iam_policy_document.apply_trust.json
  max_session_duration = 3600
  permissions_boundary = local.boundary_arn
}

data "aws_iam_policy_document" "state_access" {
  statement {
    sid       = "ListOnlyThisStatePrefix"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket_name}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = [var.state_key, "${var.state_key}.tflock", "02-iam-oidc/*"]
    }
  }

  statement {
    sid     = "ReadWriteOnlyStateAndLock"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      local.state_object_arn,
      local.state_lock_arn,
      "arn:aws:s3:::${var.state_bucket_name}/02-iam-oidc/*"
    ]
  }
}

resource "aws_iam_policy" "state_access" {
  name   = "portfolio-gh-state-access"
  path   = local.role_path
  policy = data.aws_iam_policy_document.state_access.json
}

resource "aws_iam_role_policy_attachment" "plan_state_access" {
  role       = aws_iam_role.plan.name
  policy_arn = aws_iam_policy.state_access.arn
}

data "aws_iam_policy_document" "portfolio_boundary" {
  statement {
    sid       = "AllowIdentityChecks"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity", "iam:SimulatePrincipalPolicy"]
    resources = ["*"]
  }

  statement {
    sid       = "AllowStateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket_name}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = [var.state_key, "${var.state_key}.tflock", "02-iam-oidc/*"]
    }
  }

  statement {
    sid     = "AllowStateObjects"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      local.state_object_arn,
      local.state_lock_arn,
      "arn:aws:s3:::${var.state_bucket_name}/02-iam-oidc/*"
    ]
  }

  statement {
    sid    = "AllowShowcaseWorkload"
    effect = "Allow"
    actions = [
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:StopInstances",
      "ec2:StartInstances",
      "ec2:Describe*",
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:ModifyVpcAttribute",
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:AttachNetworkInterface",
      "ec2:DetachNetworkInterface",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ssm:GetParameter",
      "ssm:GetParameters"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowBoundedTestRolesOnly"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePermissionsBoundary",
      "iam:PutRolePolicy",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role${local.role_path}*"]

    condition {
      test     = "ArnEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.boundary_arn]
    }
  }

  statement {
    sid    = "DenyBoundaryMutation"
    effect = "Deny"
    actions = [
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
    ]
    resources = [local.boundary_arn]
  }
}

resource "aws_iam_policy" "portfolio_boundary" {
  name        = "portfolio-boundary"
  path        = local.role_path
  description = "Maximum permissions for roles created by the portfolio OIDC apply role."
  policy      = data.aws_iam_policy_document.portfolio_boundary.json
}

data "aws_iam_policy_document" "apply_permissions" {
  source_policy_documents = [data.aws_iam_policy_document.portfolio_boundary.json]

  statement {
    sid    = "DenyIdentityControlPlaneMutation"
    effect = "Deny"
    actions = [
      "iam:DeleteOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:UpdateOpenIDConnectProviderClientID",
      "iam:UpdateAssumeRolePolicy",
      "iam:DeleteRolePermissionsBoundary",
    ]
    resources = [
      aws_iam_openid_connect_provider.github_actions.arn,
      aws_iam_role.plan.arn,
      aws_iam_role.apply.arn,
    ]
  }
}

resource "aws_iam_role_policy" "apply_permissions" {
  name   = "portfolio-gh-apply"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply_permissions.json
}
