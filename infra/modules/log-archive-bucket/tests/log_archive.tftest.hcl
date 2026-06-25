mock_provider "aws" {}

run "disabled_for_control_tower_owned_bucket" {
  command = plan

  variables {
    create_bucket               = false
    control_tower_owned_bucket  = true
    kms_administrator_role_arns = []
    tags = {
      Project     = "multi-account-landing-zone"
      Environment = "logging"
      Owner       = "platform-team"
      ManagedBy   = "terraform"
      CostCenter  = "test"
    }
  }

  assert {
    condition     = length(aws_s3_bucket.log_archive) == 0
    error_message = "The module must create no bucket for Control Tower-owned logging."
  }
}

run "plan_terraform_owned_extension_bucket" {
  command = plan

  variables {
    create_bucket              = true
    control_tower_owned_bucket = false
    bucket_name                = "example-log-extension-bucket-123456789012"
    create_kms_key             = true
    current_account_id         = "111111111111"
    kms_key_alias              = "log-extension-test"
    kms_administrator_role_arns = [
      "arn:aws:iam::111111111111:role/LogArchiveKmsAdminRole",
    ]
    log_reader_role_arns = [
      "arn:aws:iam::222222222222:role/SecurityAuditRole",
    ]
    cloudtrail_source_arns = [
      "arn:aws:cloudtrail:eu-west-1:111111111111:trail/manual-org-trail",
    ]
    flow_log_sources = {
      development = {
        account_id = "333333333333"
        regions    = ["eu-west-1", "eu-west-2"]
        prefix     = "vpc-flow-logs"
      }
    }
    tags = {
      Project     = "multi-account-landing-zone"
      Environment = "logging"
      Owner       = "platform-team"
      ManagedBy   = "terraform"
      CostCenter  = "test"
    }
  }

  assert {
    condition     = length(aws_s3_bucket.log_archive) == 1
    error_message = "A Terraform-owned extension bucket should be planned only when explicitly enabled."
  }

  assert {
    condition     = length(aws_s3_bucket_public_access_block.log_archive) == 1
    error_message = "Public access blocking is required."
  }

  assert {
    condition     = length(aws_s3_bucket_versioning.log_archive) == 1
    error_message = "Versioning is required."
  }

  assert {
    condition     = length(aws_s3_bucket_policy.log_archive) == 1
    error_message = "Bucket policy must be planned for a Terraform-owned log bucket."
  }

  assert {
    condition     = length(aws_kms_key.log_archive) == 1
    error_message = "KMS key must be planned when create_kms_key=true."
  }
}

run "reject_control_tower_bucket_management" {
  command = plan

  variables {
    create_bucket              = true
    control_tower_owned_bucket = true
    bucket_name                = "example-control-tower-owned-bucket"
    kms_key_arn                = "arn:aws:kms:eu-west-1:111111111111:key/11111111-1111-1111-1111-111111111111"
    tags = {
      Project     = "multi-account-landing-zone"
      Environment = "logging"
      Owner       = "platform-team"
      ManagedBy   = "terraform"
      CostCenter  = "test"
    }
  }

  assert {
    condition     = length(aws_s3_bucket.log_archive) == 0
    error_message = "Control Tower-owned buckets must not be managed."
  }
}
