locals {
  region_approved = contains(var.approved_regions, var.aws_region)
  cost_approved   = var.cost_approval == "I approve the recurring security baseline cost and reviewed Terraform plan"

  is_management_delegation = var.deployment_scope == "management-delegation"
  is_security_regional     = var.deployment_scope == "security-regional"
  is_member_account        = var.deployment_scope == "member-account"

  guardduty_delegation_enabled   = local.is_management_delegation && local.cost_approved && var.enable_guardduty_delegated_admin
  securityhub_delegation_enabled = local.is_management_delegation && local.cost_approved && var.enable_securityhub_delegated_admin
  access_analyzer_delegation_enabled = (
    local.is_management_delegation &&
    local.cost_approved &&
    var.enable_access_analyzer_delegated_admin
  )
  inspector_delegation_enabled = local.is_management_delegation && local.cost_approved && var.enable_inspector_delegated_admin
  macie_delegation_enabled     = local.is_management_delegation && local.cost_approved && var.enable_macie_delegated_admin

  guardduty_enabled   = local.is_security_regional && local.cost_approved && var.enable_guardduty
  securityhub_enabled = local.is_security_regional && local.cost_approved && var.enable_securityhub
  access_analyzer_enabled = (
    local.is_security_regional &&
    local.cost_approved &&
    var.enable_access_analyzer
  )
  config_aggregator_enabled = (
    local.is_security_regional &&
    local.cost_approved &&
    var.enable_config_aggregator &&
    !var.control_tower_manages_config
  )
  s3_account_public_access_block_enabled = (
    (local.is_security_regional || local.is_member_account) &&
    var.enable_s3_account_public_access_block
  )
  inspector_enabled = (
    (local.is_security_regional || local.is_member_account) &&
    local.cost_approved &&
    var.enable_inspector
  )
  macie_enabled = (
    (local.is_security_regional || local.is_member_account) &&
    local.cost_approved &&
    var.enable_macie
  )
  alert_routing_enabled = local.is_security_regional && var.enable_alert_routing && var.alert_target_arn != null
}

resource "terraform_data" "guardrails" {
  input = {
    deployment_scope = var.deployment_scope
    aws_region       = var.aws_region
    current_account  = var.current_account_id
  }

  lifecycle {
    precondition {
      condition     = local.region_approved
      error_message = "aws_region must be listed in approved_regions."
    }

    precondition {
      condition = (
        !local.is_management_delegation ||
        var.current_account_id == var.management_account_id
      )
      error_message = "management-delegation plans must run with management account credentials."
    }

    precondition {
      condition = (
        !local.is_security_regional ||
        var.current_account_id == var.security_account_id
      )
      error_message = "security-regional plans must run with security account credentials."
    }

    precondition {
      condition = !(
        var.control_tower_manages_config &&
        var.enable_config_aggregator
      )
      error_message = "Config aggregation cannot be enabled here until Control Tower Config ownership is reviewed and control_tower_manages_config=false."
    }

    precondition {
      condition = !(
        local.config_aggregator_enabled &&
        var.config_aggregator_role_arn == null
      )
      error_message = "config_aggregator_role_arn is required when creating a Config organization aggregator."
    }

    precondition {
      condition = !(
        (var.enable_guardduty || var.enable_securityhub || var.enable_access_analyzer || var.enable_config_aggregator || var.enable_inspector || var.enable_macie || var.enable_access_analyzer_delegated_admin) &&
        !local.cost_approved
      )
      error_message = "Paid/security service enablement requires explicit cost_approval."
    }
  }
}

resource "aws_guardduty_organization_admin_account" "security" {
  count = local.guardduty_delegation_enabled ? 1 : 0

  admin_account_id = var.security_account_id
}

resource "aws_securityhub_organization_admin_account" "security" {
  count = local.securityhub_delegation_enabled ? 1 : 0

  admin_account_id = var.security_account_id
}

resource "aws_organizations_delegated_administrator" "access_analyzer" {
  count = local.access_analyzer_delegation_enabled ? 1 : 0

  account_id        = var.security_account_id
  service_principal = "access-analyzer.amazonaws.com"
}

resource "aws_inspector2_delegated_admin_account" "security" {
  count = local.inspector_delegation_enabled ? 1 : 0

  account_id = var.security_account_id
}

resource "aws_macie2_organization_admin_account" "security" {
  count = local.macie_delegation_enabled ? 1 : 0

  admin_account_id = var.security_account_id
}

resource "aws_guardduty_detector" "security" {
  count = local.guardduty_enabled ? 1 : 0

  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  tags                         = var.tags
}

resource "aws_guardduty_organization_configuration" "security" {
  count = local.guardduty_enabled ? 1 : 0

  detector_id                      = aws_guardduty_detector.security[0].id
  auto_enable_organization_members = var.guardduty_auto_enable_organization_members
}

resource "aws_securityhub_account" "security" {
  count = local.securityhub_enabled ? 1 : 0

  enable_default_standards  = false
  auto_enable_controls      = true
  control_finding_generator = "SECURITY_CONTROL"
}

resource "aws_securityhub_organization_configuration" "security" {
  count = local.securityhub_enabled ? 1 : 0

  auto_enable           = var.securityhub_auto_enable
  auto_enable_standards = var.securityhub_auto_enable_standards

  depends_on = [aws_securityhub_account.security]
}

resource "aws_securityhub_finding_aggregator" "security" {
  count = local.securityhub_enabled && var.enable_securityhub_finding_aggregator ? 1 : 0

  linking_mode      = length(var.securityhub_finding_aggregation_regions) > 0 ? "SPECIFIED_REGIONS" : "ALL_REGIONS"
  specified_regions = length(var.securityhub_finding_aggregation_regions) > 0 ? sort(tolist(var.securityhub_finding_aggregation_regions)) : null

  depends_on = [aws_securityhub_account.security]
}

resource "aws_accessanalyzer_analyzer" "organization_external_access" {
  count = local.access_analyzer_enabled ? 1 : 0

  analyzer_name = var.access_analyzer_name
  type          = "ORGANIZATION"
  tags          = var.tags
}

resource "aws_config_configuration_aggregator" "organization" {
  count = local.config_aggregator_enabled ? 1 : 0

  name = var.config_aggregator_name
  tags = var.tags

  organization_aggregation_source {
    all_regions = false
    regions     = sort(tolist(var.approved_regions))
    role_arn    = var.config_aggregator_role_arn
  }
}

resource "aws_s3_account_public_access_block" "this" {
  count = local.s3_account_public_access_block_enabled ? 1 : 0

  account_id              = var.current_account_id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_inspector2_enabler" "this" {
  count = local.inspector_enabled ? 1 : 0

  account_ids    = [var.current_account_id]
  resource_types = sort(tolist(var.inspector_resource_types))
}

resource "aws_inspector2_organization_configuration" "security" {
  count = local.is_security_regional && local.cost_approved && var.enable_inspector ? 1 : 0

  auto_enable {
    ec2             = contains(var.inspector_resource_types, "EC2")
    ecr             = contains(var.inspector_resource_types, "ECR")
    lambda          = contains(var.inspector_resource_types, "LAMBDA")
    lambda_code     = contains(var.inspector_resource_types, "LAMBDA_CODE")
    code_repository = contains(var.inspector_resource_types, "CODE_REPOSITORY")
  }
}

resource "aws_macie2_account" "this" {
  count = local.macie_enabled ? 1 : 0

  finding_publishing_frequency = var.macie_finding_publishing_frequency
  status                       = "ENABLED"
}

resource "aws_macie2_organization_configuration" "security" {
  count = local.is_security_regional && local.cost_approved && var.enable_macie ? 1 : 0

  auto_enable = true

  depends_on = [aws_macie2_account.this]
}

resource "aws_cloudwatch_event_rule" "security_findings" {
  count = local.alert_routing_enabled ? 1 : 0

  name           = "security-baseline-security-findings"
  description    = "Route security findings to the approved security operations target for downstream severity handling."
  event_bus_name = var.alert_event_bus_name
  event_pattern = jsonencode({
    source = [
      "aws.guardduty",
      "aws.securityhub",
      "aws.access-analyzer",
      "aws.inspector2",
      "aws.macie",
    ]
    "detail-type" = [
      "GuardDuty Finding",
      "Security Hub Findings - Imported",
      "Access Analyzer Finding",
      "Inspector2 Finding",
      "Macie Finding",
    ]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "security_findings" {
  count = local.alert_routing_enabled ? 1 : 0

  rule           = aws_cloudwatch_event_rule.security_findings[0].name
  event_bus_name = var.alert_event_bus_name
  target_id      = "security-operations"
  arn            = var.alert_target_arn
}
