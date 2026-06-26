mock_provider "aws" {}

variables {
  approved_regions      = ["eu-west-1", "eu-west-2"]
  aws_region            = "eu-west-1"
  current_account_id    = "222222222222"
  management_account_id = "111111111111"
  security_account_id   = "222222222222"
  tags = {
    Project     = "multi-account-landing-zone"
    Environment = "security"
    Owner       = "platform-team"
    ManagedBy   = "terraform"
    CostCenter  = "test"
  }
}

run "default_plan_creates_nothing_paid" {
  command = plan

  assert {
    condition     = length(aws_guardduty_detector.security) == 0
    error_message = "GuardDuty must not be enabled by default."
  }

  assert {
    condition     = length(aws_securityhub_account.security) == 0
    error_message = "Security Hub must not be enabled by default."
  }

  assert {
    condition     = length(aws_config_configuration_aggregator.organization) == 0
    error_message = "Config aggregation must not be enabled by default."
  }
}

run "plan_management_delegation_after_cost_approval" {
  command = plan

  variables {
    deployment_scope                       = "management-delegation"
    current_account_id                     = "111111111111"
    enable_guardduty_delegated_admin       = true
    enable_securityhub_delegated_admin     = true
    enable_access_analyzer_delegated_admin = true
    enable_inspector_delegated_admin       = true
    enable_macie_delegated_admin           = true
    cost_approval                          = "I approve the recurring security baseline cost and reviewed Terraform plan"
  }

  assert {
    condition     = length(aws_guardduty_organization_admin_account.security) == 1
    error_message = "GuardDuty delegated administrator should be planned only after explicit approval."
  }

  assert {
    condition     = length(aws_securityhub_organization_admin_account.security) == 1
    error_message = "Security Hub delegated administrator should be planned only after explicit approval."
  }

  assert {
    condition     = length(aws_organizations_delegated_administrator.access_analyzer) == 1
    error_message = "Access Analyzer delegated administrator should be planned only after explicit approval."
  }
}

run "plan_security_regional_after_cost_approval" {
  command = plan

  variables {
    deployment_scope                        = "security-regional"
    current_account_id                      = "222222222222"
    enable_guardduty                        = true
    enable_securityhub                      = true
    enable_securityhub_finding_aggregator   = true
    securityhub_finding_aggregation_regions = ["eu-west-1", "eu-west-2"]
    enable_access_analyzer                  = true
    enable_s3_account_public_access_block   = true
    enable_alert_routing                    = true
    alert_target_arn                        = "arn:aws:sns:eu-west-1:222222222222:security-critical-alerts"
    cost_approval                           = "I approve the recurring security baseline cost and reviewed Terraform plan"
  }

  assert {
    condition     = length(aws_guardduty_detector.security) == 1
    error_message = "Security regional plan should create a GuardDuty detector when explicitly approved."
  }

  assert {
    condition     = length(aws_securityhub_account.security) == 1
    error_message = "Security regional plan should enable Security Hub when explicitly approved."
  }

  assert {
    condition     = length(aws_accessanalyzer_analyzer.organization_external_access) == 1
    error_message = "Security regional plan should create an organization Access Analyzer when explicitly approved."
  }

  assert {
    condition     = length(aws_cloudwatch_event_rule.security_findings) == 1
    error_message = "Alert routing should be planned when a target ARN is approved."
  }
}

run "reject_config_aggregator_when_control_tower_manages_config" {
  command = plan

  variables {
    deployment_scope             = "security-regional"
    current_account_id           = "222222222222"
    enable_config_aggregator     = true
    control_tower_manages_config = true
    cost_approval                = "I approve the recurring security baseline cost and reviewed Terraform plan"
  }

  expect_failures = [terraform_data.guardrails]
}

run "reject_paid_service_without_cost_approval" {
  command = plan

  variables {
    deployment_scope   = "security-regional"
    current_account_id = "222222222222"
    enable_guardduty   = true
  }

  expect_failures = [terraform_data.guardrails]
}
