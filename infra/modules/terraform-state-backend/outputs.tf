output "bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state."
  value       = aws_s3_bucket.terraform_state.id
}

output "bucket_arn" {
  description = "ARN of the Terraform state bucket."
  value       = aws_s3_bucket.terraform_state.arn
}

output "bucket_region" {
  description = "AWS Region containing the Terraform state bucket."
  value       = data.aws_region.current.region
}

output "bucket_account_id" {
  description = "AWS account ID that owns the Terraform state bucket."
  value       = data.aws_caller_identity.current.account_id
}

output "kms_key_arn" {
  description = "ARN of the customer-managed KMS key used for state encryption."
  value       = aws_kms_key.terraform_state.arn
}

output "kms_key_alias" {
  description = "Alias of the customer-managed KMS key."
  value       = aws_kms_alias.terraform_state.name
}

output "backend_configuration" {
  description = "Non-secret values required by S3 backend blocks. The key remains environment-specific."
  value = {
    bucket                = aws_s3_bucket.terraform_state.id
    region                = data.aws_region.current.region
    encrypt               = true
    kms_key_id            = aws_kms_key.terraform_state.arn
    use_lockfile          = true
    expected_bucket_owner = data.aws_caller_identity.current.account_id
    allowed_account_ids   = [data.aws_caller_identity.current.account_id]
  }
}

output "state_access_policy_json" {
  description = "Least-privilege identity policy JSON keyed by state_access_principals map key. Attach each policy only to its matching principal."
  value = {
    for name, document in data.aws_iam_policy_document.state_access : name => document.json
  }
}
