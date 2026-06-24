module "terraform_state_backend" {
  source = "../../modules/terraform-state-backend"

  bucket_name_prefix = var.bucket_name_prefix

  bucket_administrator_arns = var.bucket_administrator_arns
  kms_administrator_arns    = var.kms_administrator_arns
  state_access_principals   = var.state_access_principals

  noncurrent_version_transition_days = var.noncurrent_version_transition_days
  noncurrent_version_archive_days    = var.noncurrent_version_archive_days
  noncurrent_version_expiration_days = var.noncurrent_version_expiration_days

  project_name    = var.project_name
  owner           = var.owner
  cost_center     = var.cost_center
  additional_tags = var.additional_tags
}
