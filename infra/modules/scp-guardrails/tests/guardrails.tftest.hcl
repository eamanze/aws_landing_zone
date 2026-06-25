mock_provider "aws" {}

run "plan_policies_without_attachments" {
  command = plan

  variables {
    tags = {
      Project     = "multi-account-landing-zone"
      Environment = "organization"
      Owner       = "platform-team"
      ManagedBy   = "terraform"
      CostCenter  = "test"
    }
  }

  assert {
    condition     = length(aws_organizations_policy.custom) == 5
    error_message = "Exactly five gap-filling custom policies must be planned."
  }

  assert {
    condition     = length(aws_organizations_policy_attachment.custom) == 0
    error_message = "Default attachment flags must plan no SCP attachments."
  }

  assert {
    condition     = alltrue([for document in values(local.policy_documents) : length(document) <= 10240])
    error_message = "Every compact policy must remain within the current 10,240-character limit."
  }

  assert {
    condition = alltrue(flatten([
      for document in values(local.policy_documents) : [
        for statement in jsondecode(document).Statement : statement.Effect == "Deny"
      ]
    ]))
    error_message = "Custom SCPs must contain deny statements only."
  }

  assert {
    condition     = strcontains(local.policy_documents["protect_security_services"], "arn:aws:iam::*:role/AWSControlTowerExecution")
    error_message = "Conditional policies must preserve AWSControlTowerExecution."
  }

  assert {
    condition     = !strcontains(local.policy_documents["deny_leave_organization"], "approved_exception")
    error_message = "The leave-organization deny must not expose an exception."
  }
}

run "plan_sandbox_attachments" {
  command = plan

  variables {
    target_ou_ids = ["ou-abcd-12345678"]
    policy_exception_role_arns = {
      restrict_privilege_escalation = ["arn:aws:iam::111111111111:role/SandboxIamGuardrailOperator"]
      restrict_s3_public_access     = ["arn:aws:iam::111111111111:role/SandboxS3GuardrailOperator"]
    }
    attach_deny_leave_organization       = true
    attach_protect_security_services     = true
    attach_restrict_iam_users            = true
    attach_restrict_privilege_escalation = true
    attach_restrict_s3_public_access     = true
    tags = {
      Project     = "multi-account-landing-zone"
      Environment = "sandbox"
      Owner       = "platform-team"
      ManagedBy   = "terraform"
      CostCenter  = "test"
    }
  }

  assert {
    condition     = length(aws_organizations_policy_attachment.custom) == 5
    error_message = "Five explicit flags against one Sandbox OU must plan five attachments."
  }

  assert {
    condition     = alltrue([for attachment in values(aws_organizations_policy_attachment.custom) : attachment.target_id == "ou-abcd-12345678"])
    error_message = "Every planned attachment must target the explicit Sandbox child OU."
  }

  assert {
    condition     = !contains([for attachment in values(aws_organizations_policy_attachment.custom) : attachment.target_id], "r-root")
    error_message = "No policy may attach to Root."
  }

  assert {
    condition     = strcontains(local.policy_documents["restrict_privilege_escalation"], "arn:aws:iam::111111111111:role/SandboxIamGuardrailOperator")
    error_message = "The exact policy-specific IAM exception role must appear in the privilege-escalation policy JSON."
  }

  assert {
    condition     = !strcontains(local.policy_documents["restrict_iam_users"], "arn:aws:iam::111111111111:role/SandboxIamGuardrailOperator")
    error_message = "Policy-specific exceptions must not leak into other conditional policies."
  }

  assert {
    condition     = strcontains(local.policy_documents["restrict_s3_public_access"], "arn:aws:iam::111111111111:role/SandboxS3GuardrailOperator")
    error_message = "The exact policy-specific S3 exception role must appear in the S3 policy JSON."
  }
}

run "reject_root_target" {
  command = plan

  variables {
    target_ou_ids                  = ["r-abcd"]
    attach_deny_leave_organization = true
    tags = {
      Project     = "multi-account-landing-zone"
      Environment = "test"
      Owner       = "platform-team"
      ManagedBy   = "terraform"
      CostCenter  = "test"
    }
  }

  expect_failures = [var.target_ou_ids]
}

run "reject_wildcard_exception_role" {
  command = plan

  variables {
    approved_exception_role_arns = ["arn:aws:iam::111111111111:role/*"]
    tags = {
      Project     = "multi-account-landing-zone"
      Environment = "test"
      Owner       = "platform-team"
      ManagedBy   = "terraform"
      CostCenter  = "test"
    }
  }

  expect_failures = [var.approved_exception_role_arns]
}

run "reject_invalid_policy_exception_key" {
  command = plan

  variables {
    policy_exception_role_arns = {
      deny_leave_organization = ["arn:aws:iam::111111111111:role/InvalidException"]
    }
    tags = {
      Project     = "multi-account-landing-zone"
      Environment = "test"
      Owner       = "platform-team"
      ManagedBy   = "terraform"
      CostCenter  = "test"
    }
  }

  expect_failures = [var.policy_exception_role_arns]
}
