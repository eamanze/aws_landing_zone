locals {
  custom_policy_keys = [
    "deny_leave_organization",
    "protect_security_services",
    "restrict_iam_users",
    "restrict_privilege_escalation",
    "restrict_s3_public_access",
  ]

  # AWS documents AWSControlTowerExecution as the role used by Control Tower to
  # maintain governed account baselines. SCPs do not restrict service-linked
  # roles, but direct AWS service calls are also excluded below.
  control_tower_exception_role_patterns = [
    "arn:${var.aws_partition}:iam::*:role/AWSControlTowerExecution",
  ]

  global_exception_role_arns = sort(tolist(var.approved_exception_role_arns))

  policy_exception_role_arns = {
    for key in local.custom_policy_keys : key => sort(tolist(lookup(var.policy_exception_role_arns, key, [])))
  }

  exception_conditions_by_policy = {
    for key in local.custom_policy_keys : key => {
      ArnNotLike = {
        "aws:PrincipalARN" = concat(
          local.control_tower_exception_role_patterns,
          local.global_exception_role_arns,
          local.policy_exception_role_arns[key],
        )
      }
      Bool = {
        "aws:PrincipalIsAWSService" = "false"
      }
    }
  }

  policy_documents = {
    deny_leave_organization = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "DenyLeavingOrganization"
          Effect   = "Deny"
          Action   = ["organizations:LeaveOrganization"]
          Resource = "*"
        }
      ]
    })

    protect_security_services = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "ProtectGuardDutyConfiguration"
          Effect = "Deny"
          Action = [
            "guardduty:DeleteDetector",
            "guardduty:DeleteMembers",
            "guardduty:DisableOrganizationAdminAccount",
            "guardduty:DisassociateFromAdministratorAccount",
            "guardduty:DisassociateMembers",
            "guardduty:StopMonitoringMembers",
            "guardduty:UpdateOrganizationConfiguration",
          ]
          Resource  = "*"
          Condition = local.exception_conditions_by_policy.protect_security_services
        },
        {
          Sid    = "ProtectSecurityHubConfiguration"
          Effect = "Deny"
          Action = [
            "securityhub:DeleteMembers",
            "securityhub:DisableOrganizationAdminAccount",
            "securityhub:DisableSecurityHub",
            "securityhub:DisassociateFromAdministratorAccount",
            "securityhub:DisassociateMembers",
            "securityhub:UpdateOrganizationConfiguration",
          ]
          Resource  = "*"
          Condition = local.exception_conditions_by_policy.protect_security_services
        },
        {
          Sid       = "ProtectAccessAnalyzers"
          Effect    = "Deny"
          Action    = ["access-analyzer:DeleteAnalyzer"]
          Resource  = "*"
          Condition = local.exception_conditions_by_policy.protect_security_services
        },
      ]
    })

    restrict_iam_users = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "DenyIamUsersAndLongLivedCredentials"
          Effect = "Deny"
          Action = [
            "iam:CreateAccessKey",
            "iam:CreateLoginProfile",
            "iam:CreateUser",
            "iam:UpdateAccessKey",
            "iam:UpdateLoginProfile",
          ]
          Resource  = "arn:${var.aws_partition}:iam::*:user/*"
          Condition = local.exception_conditions_by_policy.restrict_iam_users
        }
      ]
    })

    restrict_privilege_escalation = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "DenyUnapprovedPrivilegeEscalation"
          Effect = "Deny"
          Action = [
            "iam:AddUserToGroup",
            "iam:AttachGroupPolicy",
            "iam:AttachRolePolicy",
            "iam:AttachUserPolicy",
            "iam:CreatePolicyVersion",
            "iam:DeleteRolePermissionsBoundary",
            "iam:DeleteUserPermissionsBoundary",
            "iam:PassRole",
            "iam:PutGroupPolicy",
            "iam:PutRolePermissionsBoundary",
            "iam:PutRolePolicy",
            "iam:PutUserPermissionsBoundary",
            "iam:PutUserPolicy",
            "iam:SetDefaultPolicyVersion",
            "iam:UpdateAssumeRolePolicy",
          ]
          Resource  = "*"
          Condition = local.exception_conditions_by_policy.restrict_privilege_escalation
        }
      ]
    })

    restrict_s3_public_access = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "DenyPublicCannedAcls"
          Effect = "Deny"
          Action = [
            "s3:PutBucketAcl",
            "s3:PutObjectAcl",
          ]
          Resource = "*"
          Condition = merge(local.exception_conditions_by_policy.restrict_s3_public_access, {
            StringEquals = {
              "s3:x-amz-acl" = [
                "authenticated-read",
                "public-read",
                "public-read-write",
              ]
            }
          })
        },
        {
          Sid    = "DenyBlockPublicAccessTampering"
          Effect = "Deny"
          Action = [
            "s3:DeleteAccountPublicAccessBlock",
            "s3:DeleteBucketPublicAccessBlock",
            "s3:PutAccountPublicAccessBlock",
            "s3:PutBucketPublicAccessBlock",
          ]
          Resource  = "*"
          Condition = local.exception_conditions_by_policy.restrict_s3_public_access
        },
      ]
    })
  }

  policy_metadata = {
    deny_leave_organization = {
      name        = "landing-zone-deny-leaving-organization"
      description = "Prevents member accounts from leaving AWS Organizations."
    }
    protect_security_services = {
      name        = "landing-zone-protect-security-services"
      description = "Protects GuardDuty, Security Hub CSPM, and IAM Access Analyzer organization configuration."
    }
    restrict_iam_users = {
      name        = "landing-zone-restrict-iam-users"
      description = "Requires federation by restricting IAM users, console passwords, and long-lived access keys."
    }
    restrict_privilege_escalation = {
      name        = "landing-zone-restrict-privilege-escalation"
      description = "Restricts high-risk IAM policy, trust, boundary, group, and PassRole operations."
    }
    restrict_s3_public_access = {
      name        = "landing-zone-restrict-s3-public-access"
      description = "Restricts public ACLs and tampering with S3 Block Public Access settings."
    }
  }

  attachment_flags = {
    deny_leave_organization       = var.attach_deny_leave_organization
    protect_security_services     = var.attach_protect_security_services
    restrict_iam_users            = var.attach_restrict_iam_users
    restrict_privilege_escalation = var.attach_restrict_privilege_escalation
    restrict_s3_public_access     = var.attach_restrict_s3_public_access
  }

  enabled_attachment_pairs = flatten([
    for policy_key, enabled in local.attachment_flags : enabled ? [
      for ou_id in var.target_ou_ids : {
        key        = "${policy_key}:${ou_id}"
        policy_key = policy_key
        ou_id      = ou_id
      }
    ] : []
  ])

  attachments = {
    for pair in local.enabled_attachment_pairs : pair.key => pair
  }
}

resource "aws_organizations_policy" "custom" {
  for_each = local.policy_documents

  name        = local.policy_metadata[each.key].name
  description = local.policy_metadata[each.key].description
  type        = "SERVICE_CONTROL_POLICY"
  content     = each.value
  tags        = var.tags

  lifecycle {
    precondition {
      condition     = length(each.value) <= 10240
      error_message = "The compact SCP exceeds the current AWS Organizations 10,240-character policy-document limit."
    }
  }
}

resource "aws_organizations_policy_attachment" "custom" {
  for_each = local.attachments

  policy_id = aws_organizations_policy.custom[each.value.policy_key].id
  target_id = each.value.ou_id
}
