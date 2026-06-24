output "bucket_name" {
  description = "S3 bucket name to configure in every Terraform backend."
  value       = module.terraform_state_backend.bucket_name
}

output "bucket_arn" {
  description = "S3 bucket ARN."
  value       = module.terraform_state_backend.bucket_arn
}

output "bucket_region" {
  description = "S3 bucket Region."
  value       = module.terraform_state_backend.bucket_region
}

output "bucket_account_id" {
  description = "AWS account ID that owns the state bucket."
  value       = module.terraform_state_backend.bucket_account_id
}

output "kms_key_arn" {
  description = "KMS key ARN to configure in every Terraform backend."
  value       = module.terraform_state_backend.kms_key_arn
}

output "kms_key_alias" {
  description = "KMS key alias."
  value       = module.terraform_state_backend.kms_key_alias
}

output "backend_configuration" {
  description = "Shared non-secret S3 backend values; each environment adds its own key."
  value       = module.terraform_state_backend.backend_configuration
}

output "state_access_policy_json" {
  description = "Least-privilege identity policy JSON for each named state principal."
  value       = module.terraform_state_backend.state_access_policy_json
}
