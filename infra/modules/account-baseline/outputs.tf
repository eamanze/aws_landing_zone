output "role_arns" {
  description = "Canonical baseline role ARNs."
  value       = module.cross_account_roles.role_arns
}

output "role_names" {
  description = "Canonical baseline role names."
  value       = module.cross_account_roles.role_names
}

output "break_glass_monitoring_rule_arn" {
  description = "EventBridge rule ARN that detects BreakGlassAdminRole assumptions, or null when the role is disabled."
  value       = try(aws_cloudwatch_event_rule.break_glass_assumption[0].arn, null)
}
