output "policy_ids" {
  description = "Custom SCP key-to-policy-ID map."
  value       = { for key, policy in aws_organizations_policy.custom : key => policy.id }
}

output "policy_arns" {
  description = "Custom SCP key-to-policy-ARN map."
  value       = { for key, policy in aws_organizations_policy.custom : key => policy.arn }
}

output "policy_documents" {
  description = "Compact generated SCP JSON for review and validation."
  value       = local.policy_documents
}

output "policy_sizes" {
  description = "Generated compact JSON character counts compared with the current 10,240-character SCP limit."
  value       = { for key, document in local.policy_documents : key => length(document) }
}

output "attachment_targets" {
  description = "Planned policy-to-child-OU attachments. Empty when all attachment flags retain their false defaults."
  value = {
    for key, attachment in local.attachments : key => {
      policy_key = attachment.policy_key
      target_id  = attachment.ou_id
    }
  }
}

output "exception_role_arns_by_policy" {
  description = "Effective exact exception role ARNs by policy, excluding the built-in AWSControlTowerExecution role-name pattern."
  value = {
    for key in local.custom_policy_keys : key => concat(
      local.global_exception_role_arns,
      local.policy_exception_role_arns[key],
    )
  }
}
