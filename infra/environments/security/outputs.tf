output "security_baseline" {
  description = "Security baseline plan outputs."
  value = {
    planned_scope          = module.security_baseline.planned_scope
    planned_region         = module.security_baseline.planned_region
    guardduty_detector_id  = module.security_baseline.guardduty_detector_id
    securityhub_account_id = module.security_baseline.securityhub_account_id
    access_analyzer_arn    = module.security_baseline.access_analyzer_arn
    config_aggregator_arn  = module.security_baseline.config_aggregator_arn
    alert_rule_arn         = module.security_baseline.alert_rule_arn
  }
}
