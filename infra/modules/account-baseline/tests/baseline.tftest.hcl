mock_provider "aws" {}

run "plan_complete_non_aft_baseline" {
  command = plan

  variables {
    account_type = "management"
    enabled_roles = [
      "OrganizationAdminRole",
      "SecurityAuditRole",
      "NetworkAdminRole",
      "TerraformExecutionRole",
      "ReadOnlyRole",
      "IncidentResponseRole",
      "BreakGlassAdminRole",
    ]
    human_trusted_principal_arns = {
      OrganizationAdminRole = ["arn:aws:iam::111111111111:role/IdentityCenterOrganizationAdmin"]
      SecurityAuditRole     = ["arn:aws:iam::111111111111:role/IdentityCenterSecurityAudit"]
      NetworkAdminRole      = ["arn:aws:iam::111111111111:role/IdentityCenterNetworkAdmin"]
      ReadOnlyRole          = ["arn:aws:iam::111111111111:role/IdentityCenterReadOnly"]
      IncidentResponseRole  = ["arn:aws:iam::111111111111:role/IdentityCenterIncidentResponse"]
      BreakGlassAdminRole   = ["arn:aws:iam::111111111111:role/EmergencyAccessCustodian"]
    }
    terraform_oidc = {
      provider_arn = "arn:aws:iam::111111111111:oidc-provider/token.actions.githubusercontent.com"
      issuer       = "token.actions.githubusercontent.com"
      audiences    = ["sts.amazonaws.com"]
      subjects     = ["repo:example/landing-zone:environment:management"]
    }
    additional_managed_policy_arns = {
      TerraformExecutionRole = ["arn:aws:iam::111111111111:policy/TerraformManagement"]
    }
    permissions_boundary_arn     = "arn:aws:iam::111111111111:policy/LandingZoneBoundary"
    break_glass_acknowledgement  = "I acknowledge monitored emergency administrator access"
    break_glass_alert_target_arn = "arn:aws:sns:eu-west-1:111111111111:security-alerts"
    enable_aft                   = false
    tags = {
      Project     = "multi-account-landing-zone"
      Environment = "management"
      Owner       = "platform-team"
      ManagedBy   = "terraform"
      CostCenter  = "test"
    }
  }

  assert {
    condition     = length(output.role_arns) == 7
    error_message = "The complete non-AFT baseline must plan seven roles."
  }

  assert {
    condition     = !contains(keys(output.role_arns), "AFTExecutionRole")
    error_message = "AFTExecutionRole must be absent while AFT is disabled."
  }

  assert {
    condition     = aws_cloudwatch_event_rule.break_glass_assumption[0].state == "ENABLED"
    error_message = "Break-glass event monitoring must be enabled."
  }

  assert {
    condition     = aws_cloudwatch_event_target.break_glass_alert[0].arn == "arn:aws:sns:eu-west-1:111111111111:security-alerts"
    error_message = "Break-glass events must target the exact configured security alert ARN."
  }
}

run "plan_aft_role_only_when_enabled" {
  command = plan

  variables {
    account_type  = "aft"
    enabled_roles = ["AFTExecutionRole"]
    enable_aft    = true
    automation_trusted_principal_arns = {
      AFTExecutionRole = ["arn:aws:iam::111111111111:role/AFTPipelineRole"]
    }
    additional_managed_policy_arns = {
      AFTExecutionRole = ["arn:aws:iam::111111111111:policy/AFTExecution"]
    }
    permissions_boundary_arn = "arn:aws:iam::111111111111:policy/LandingZoneBoundary"
    tags = {
      Project     = "multi-account-landing-zone"
      Environment = "aft"
      Owner       = "platform-team"
      ManagedBy   = "terraform"
      CostCenter  = "test"
    }
  }

  assert {
    condition     = keys(output.role_arns) == ["AFTExecutionRole"]
    error_message = "The AFT baseline must plan only the explicitly enabled AFT role."
  }
}
