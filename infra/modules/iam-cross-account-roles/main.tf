locals {
  trust_statements = {
    for name, role in var.role_definitions : name => concat(
      length(role.trusted_aws_principal_arns) == 0 ? [] : [
        merge(
          {
            Sid    = "ExplicitAwsRoleTrust"
            Effect = "Allow"
            Principal = {
              AWS = sort(tolist(role.trusted_aws_principal_arns))
            }
            Action = "sts:AssumeRole"
          },
          role.require_mfa ? {
            Condition = {
              Bool = {
                "aws:MultiFactorAuthPresent" = "true"
              }
            }
          } : {}
        )
      ],
      role.oidc == null ? [] : [
        {
          Sid    = "ExplicitOidcTrust"
          Effect = "Allow"
          Principal = {
            Federated = role.oidc.provider_arn
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "${role.oidc.issuer}:aud" = sort(tolist(role.oidc.audiences))
              "${role.oidc.issuer}:sub" = sort(tolist(role.oidc.subjects))
            }
          }
        }
      ]
    )
  }

  managed_policy_attachments = merge({}, [
    for role_name, role in var.role_definitions : {
      for policy_arn in role.managed_policy_arns :
      "${role_name}-${sha1(policy_arn)}" => {
        role_name  = role_name
        policy_arn = policy_arn
      }
    }
  ]...)

  inline_policies = {
    for name, role in var.role_definitions : name => role.inline_policy_json
    if role.inline_policy_json != null
  }
}

resource "aws_iam_role" "this" {
  for_each = var.role_definitions

  name                 = each.key
  description          = each.value.description
  path                 = var.role_path
  max_session_duration = each.value.max_session_duration
  permissions_boundary = each.value.permissions_boundary_arn_override != null ? each.value.permissions_boundary_arn_override : var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.trust_statements[each.key]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = local.managed_policy_attachments

  role       = aws_iam_role.this[each.value.role_name].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_role_policy" "inline" {
  for_each = local.inline_policies

  name   = "${each.key}Permissions"
  role   = aws_iam_role.this[each.key].id
  policy = each.value
}
