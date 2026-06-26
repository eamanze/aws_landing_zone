output "planned_scope" {
  description = "Deployment scope for this module instance."
  value       = var.deployment_scope
}

output "planned_region" {
  description = "Approved Region for this separate plan."
  value       = var.aws_region
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID, if enabled."
  value       = try(aws_guardduty_detector.security[0].id, null)
}

output "securityhub_account_id" {
  description = "Security Hub account resource ID, if enabled."
  value       = try(aws_securityhub_account.security[0].id, null)
}

output "access_analyzer_arn" {
  description = "Organization Access Analyzer ARN, if enabled."
  value       = try(aws_accessanalyzer_analyzer.organization_external_access[0].arn, null)
}

output "config_aggregator_arn" {
  description = "AWS Config organization aggregator ARN, if enabled."
  value       = try(aws_config_configuration_aggregator.organization[0].arn, null)
}

output "alert_rule_arn" {
  description = "EventBridge alert rule ARN, if alert routing is enabled."
  value       = try(aws_cloudwatch_event_rule.security_findings[0].arn, null)
}
