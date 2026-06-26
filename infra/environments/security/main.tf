module "security_baseline" {
  source = "../../modules/security-baseline"

  deployment_scope             = var.deployment_scope
  approved_regions             = var.approved_regions
  aws_region                   = var.aws_region
  current_account_id           = var.current_account_id
  management_account_id        = var.management_account_id
  security_account_id          = var.security_account_id
  cost_approval                = var.cost_approval
  control_tower_manages_config = var.control_tower_manages_config

  enable_guardduty_delegated_admin        = var.enable_guardduty_delegated_admin
  enable_guardduty                        = var.enable_guardduty
  enable_securityhub_delegated_admin      = var.enable_securityhub_delegated_admin
  enable_securityhub                      = var.enable_securityhub
  enable_securityhub_finding_aggregator   = var.enable_securityhub_finding_aggregator
  securityhub_finding_aggregation_regions = var.securityhub_finding_aggregation_regions
  enable_access_analyzer                  = var.enable_access_analyzer
  enable_access_analyzer_delegated_admin  = var.enable_access_analyzer_delegated_admin
  enable_config_aggregator                = var.enable_config_aggregator
  config_aggregator_role_arn              = var.config_aggregator_role_arn
  enable_s3_account_public_access_block   = var.enable_s3_account_public_access_block
  enable_inspector_delegated_admin        = var.enable_inspector_delegated_admin
  enable_inspector                        = var.enable_inspector
  enable_macie_delegated_admin            = var.enable_macie_delegated_admin
  enable_macie                            = var.enable_macie
  enable_alert_routing                    = var.enable_alert_routing
  alert_target_arn                        = var.alert_target_arn
  tags                                    = var.tags
}
