output "role_arns" {
  description = "Canonical role name to ARN map."
  value       = { for name, role in aws_iam_role.this : name => role.arn }
}

output "role_names" {
  description = "Canonical role name map."
  value       = { for name, role in aws_iam_role.this : name => role.name }
}

output "trust_policies" {
  description = "Generated trust policies for review and automated validation."
  value       = { for name, role in aws_iam_role.this : name => jsondecode(role.assume_role_policy) }
}
