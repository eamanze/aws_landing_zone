mock_provider "aws" {}

run "plan_roles_without_aft" {
  command = plan

  variables {
    enable_aft               = false
    permissions_boundary_arn = "arn:aws:iam::111111111111:policy/LandingZoneBoundary"
    tags = {
      Project     = "multi-account-landing-zone"
      Environment = "test"
      Owner       = "platform-team"
      ManagedBy   = "terraform"
      CostCenter  = "test"
    }
    role_definitions = {
      OrganizationAdminRole = {
        description                = "test"
        principal_type             = "human"
        trusted_aws_principal_arns = ["arn:aws:iam::111111111111:role/IdentityCenterOrganizationAdmin"]
        require_mfa                = true
        managed_policy_arns        = ["arn:aws:iam::111111111111:policy/OrganizationAdmin"]
      }
      SecurityAuditRole = {
        description                = "test"
        principal_type             = "human"
        trusted_aws_principal_arns = ["arn:aws:iam::111111111111:role/IdentityCenterSecurityAudit"]
        require_mfa                = true
        managed_policy_arns        = ["arn:aws:iam::aws:policy/SecurityAudit"]
      }
      NetworkAdminRole = {
        description                = "test"
        principal_type             = "human"
        trusted_aws_principal_arns = ["arn:aws:iam::111111111111:role/IdentityCenterNetworkAdmin"]
        require_mfa                = true
        managed_policy_arns        = ["arn:aws:iam::aws:policy/job-function/NetworkAdministrator"]
      }
      TerraformExecutionRole = {
        description         = "test"
        principal_type      = "automation"
        require_mfa         = false
        managed_policy_arns = ["arn:aws:iam::111111111111:policy/TerraformProduction"]
        oidc = {
          provider_arn = "arn:aws:iam::111111111111:oidc-provider/token.actions.githubusercontent.com"
          issuer       = "token.actions.githubusercontent.com"
          audiences    = ["sts.amazonaws.com"]
          subjects     = ["repo:example/landing-zone:environment:production"]
        }
      }
      ReadOnlyRole = {
        description                = "test"
        principal_type             = "human"
        trusted_aws_principal_arns = ["arn:aws:iam::111111111111:role/IdentityCenterReadOnly"]
        require_mfa                = true
        managed_policy_arns        = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
      }
      IncidentResponseRole = {
        description                = "test"
        principal_type             = "human"
        trusted_aws_principal_arns = ["arn:aws:iam::111111111111:role/IdentityCenterIncidentResponse"]
        require_mfa                = true
        managed_policy_arns        = ["arn:aws:iam::aws:policy/SecurityAudit"]
      }
      BreakGlassAdminRole = {
        description                = "test"
        principal_type             = "human"
        trusted_aws_principal_arns = ["arn:aws:iam::111111111111:role/EmergencyAccessCustodian"]
        require_mfa                = true
        managed_policy_arns        = ["arn:aws:iam::aws:policy/AdministratorAccess"]
      }
    }
  }

  assert {
    condition     = length(aws_iam_role.this) == 7
    error_message = "The non-AFT baseline must plan exactly seven canonical roles."
  }

  assert {
    condition     = !contains(keys(aws_iam_role.this), "AFTExecutionRole")
    error_message = "AFTExecutionRole must not be planned while AFT is disabled."
  }

  assert {
    condition     = jsondecode(aws_iam_role.this["SecurityAuditRole"].assume_role_policy).Statement[0].Principal.AWS == ["arn:aws:iam::111111111111:role/IdentityCenterSecurityAudit"]
    error_message = "Human trust must contain only the exact configured principal."
  }

  assert {
    condition     = jsondecode(aws_iam_role.this["SecurityAuditRole"].assume_role_policy).Statement[0].Condition.Bool["aws:MultiFactorAuthPresent"] == "true"
    error_message = "Human role trust must require MFA."
  }

  assert {
    condition     = jsondecode(aws_iam_role.this["TerraformExecutionRole"].assume_role_policy).Statement[0].Principal.Federated == "arn:aws:iam::111111111111:oidc-provider/token.actions.githubusercontent.com"
    error_message = "Terraform trust must use the exact OIDC provider ARN."
  }

  assert {
    condition     = jsondecode(aws_iam_role.this["TerraformExecutionRole"].assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == ["repo:example/landing-zone:environment:production"]
    error_message = "Terraform trust must constrain the exact OIDC subject."
  }

  assert {
    condition     = !strcontains(aws_iam_role.this["TerraformExecutionRole"].assume_role_policy, "MultiFactorAuthPresent")
    error_message = "Automation trust must not require MFA."
  }

  assert {
    condition     = aws_iam_role.this["BreakGlassAdminRole"].permissions_boundary == "arn:aws:iam::111111111111:policy/LandingZoneBoundary"
    error_message = "The permissions boundary must apply to break-glass as well as normal roles."
  }
}

run "reject_wildcard_trusted_principal" {
  command = plan

  variables {
    enable_aft = false
    tags = {
      Project     = "multi-account-landing-zone"
      Environment = "test"
      Owner       = "platform-team"
      ManagedBy   = "terraform"
      CostCenter  = "test"
    }
    role_definitions = {
      ReadOnlyRole = {
        description                = "invalid wildcard test"
        principal_type             = "human"
        trusted_aws_principal_arns = ["arn:aws:iam::111111111111:role/*"]
        require_mfa                = true
        managed_policy_arns        = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
      }
    }
  }

  expect_failures = [var.role_definitions]
}
