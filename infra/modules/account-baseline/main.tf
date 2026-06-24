locals {
  human_roles = toset([
    "OrganizationAdminRole",
    "SecurityAuditRole",
    "NetworkAdminRole",
    "ReadOnlyRole",
    "IncidentResponseRole",
    "BreakGlassAdminRole",
  ])

  automation_roles = toset([
    "TerraformExecutionRole",
    "AFTExecutionRole",
  ])

  aws_managed_policy_base = "arn:${var.aws_partition}:iam::aws:policy"

  default_managed_policy_arns = {
    OrganizationAdminRole  = toset([])
    SecurityAuditRole      = toset(["${local.aws_managed_policy_base}/SecurityAudit"])
    NetworkAdminRole       = toset(["${local.aws_managed_policy_base}/job-function/NetworkAdministrator"])
    TerraformExecutionRole = toset([])
    ReadOnlyRole           = toset(["${local.aws_managed_policy_base}/ReadOnlyAccess"])
    IncidentResponseRole   = toset(["${local.aws_managed_policy_base}/SecurityAudit"])
    BreakGlassAdminRole    = toset(["${local.aws_managed_policy_base}/AdministratorAccess"])
    AFTExecutionRole       = toset([])
  }

  organization_admin_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOrganization"
        Effect = "Allow"
        Action = [
          "organizations:Describe*",
          "organizations:List*",
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageApprovedGovernancePoliciesAndDelegation"
        Effect = "Allow"
        Action = [
          "organizations:AttachPolicy",
          "organizations:CreatePolicy",
          "organizations:DeletePolicy",
          "organizations:DeregisterDelegatedAdministrator",
          "organizations:DetachPolicy",
          "organizations:DisableAWSServiceAccess",
          "organizations:EnableAWSServiceAccess",
          "organizations:RegisterDelegatedAdministrator",
          "organizations:TagResource",
          "organizations:UntagResource",
          "organizations:UpdatePolicy",
        ]
        Resource = "*"
      },
    ]
  })

  default_inline_policies = {
    OrganizationAdminRole = local.organization_admin_policy
  }

  role_descriptions = {
    OrganizationAdminRole  = "Restricted organization governance administration; management account only."
    SecurityAuditRole      = "Security review and audit access."
    NetworkAdminRole       = "Network administration for approved account network resources."
    TerraformExecutionRole = "OIDC-federated CI role for Terraform-owned account extensions."
    ReadOnlyRole           = "General read-only troubleshooting access."
    IncidentResponseRole   = "Security investigation access; containment permissions require an explicit approved policy."
    BreakGlassAdminRole    = "Emergency administrator access; monitored, MFA-protected, and reviewed after every use."
    AFTExecutionRole       = "AFT automation role; dedicated AFT account only."
  }

  role_definitions = {
    for name in var.enabled_roles : name => {
      description                = local.role_descriptions[name]
      principal_type             = contains(local.human_roles, name) ? "human" : "automation"
      trusted_aws_principal_arns = contains(local.human_roles, name) ? lookup(var.human_trusted_principal_arns, name, toset([])) : lookup(var.automation_trusted_principal_arns, name, toset([]))
      require_mfa                = contains(local.human_roles, name)
      max_session_duration       = name == "BreakGlassAdminRole" ? 3600 : 3600
      managed_policy_arns        = setunion(local.default_managed_policy_arns[name], lookup(var.additional_managed_policy_arns, name, toset([])))
      inline_policy_json         = lookup(var.inline_policy_overrides, name, lookup(local.default_inline_policies, name, null))
      oidc                       = name == "TerraformExecutionRole" ? var.terraform_oidc : null
    }
  }
}

module "cross_account_roles" {
  source = "../iam-cross-account-roles"

  role_definitions         = local.role_definitions
  enable_aft               = var.enable_aft
  role_path                = var.role_path
  permissions_boundary_arn = var.permissions_boundary_arn
  tags                     = var.tags
}

resource "aws_cloudwatch_event_rule" "break_glass_assumption" {
  count = contains(var.enabled_roles, "BreakGlassAdminRole") ? 1 : 0

  name           = "landing-zone-break-glass-assumption"
  description    = "Alert on every STS assumption of BreakGlassAdminRole."
  event_bus_name = var.break_glass_event_bus_name
  state          = "ENABLED"
  event_pattern = jsonencode({
    source        = ["aws.sts"]
    "detail-type" = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["sts.amazonaws.com"]
      eventName   = ["AssumeRole"]
      requestParameters = {
        roleArn = [module.cross_account_roles.role_arns["BreakGlassAdminRole"]]
      }
    }
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "break_glass_alert" {
  count = contains(var.enabled_roles, "BreakGlassAdminRole") ? 1 : 0

  rule           = aws_cloudwatch_event_rule.break_glass_assumption[0].name
  event_bus_name = var.break_glass_event_bus_name
  target_id      = "ImmediateSecurityAlert"
  arn            = var.break_glass_alert_target_arn
}
