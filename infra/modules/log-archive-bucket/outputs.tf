output "bucket_name" {
  description = "Terraform-owned log bucket name, or null when bucket creation is disabled."
  value       = try(aws_s3_bucket.log_archive[0].bucket, null)
}

output "bucket_arn" {
  description = "Terraform-owned log bucket ARN, or null when bucket creation is disabled."
  value       = try(aws_s3_bucket.log_archive[0].arn, null)
}

output "kms_key_arn" {
  description = "KMS key ARN used for Terraform-owned log bucket encryption."
  value       = local.effective_kms_key_arn
}

output "bucket_policy_json" {
  description = "Generated bucket policy JSON for review."
  value       = local.should_create_bucket ? local.bucket_policy_json : null
}

output "kms_policy_json" {
  description = "Generated KMS key policy JSON for review when create_kms_key=true."
  value       = local.should_create_bucket && var.create_kms_key ? local.kms_policy_json : null
}

output "vpc_flow_log_destination_arn" {
  description = "S3 destination ARN to use for Terraform-owned VPC Flow Logs."
  value       = try(aws_s3_bucket.log_archive[0].arn, null)
}
