mock_provider "aws" {}

run "disabled_for_control_tower_first" {
  command = plan

  variables {
    manual_mode_enabled   = false
    control_tower_enabled = true
    tags = {
      Project     = "multi-account-landing-zone"
      Environment = "management"
      Owner       = "platform-team"
      ManagedBy   = "terraform"
      CostCenter  = "test"
    }
  }

  assert {
    condition     = length(aws_cloudtrail.organization) == 0
    error_message = "Control Tower-first deployments must not plan a duplicate organization trail."
  }
}

run "plan_manual_mode_organization_trail" {
  command = plan

  variables {
    manual_mode_enabled        = true
    control_tower_enabled      = false
    trail_name                 = "manual-org-trail"
    s3_bucket_name             = "example-manual-log-archive-123456789012"
    kms_key_arn                = "arn:aws:kms:eu-west-1:111111111111:key/11111111-1111-1111-1111-111111111111"
    enable_log_file_validation = true
    tags = {
      Project     = "multi-account-landing-zone"
      Environment = "management"
      Owner       = "platform-team"
      ManagedBy   = "terraform"
      CostCenter  = "test"
    }
  }

  assert {
    condition     = length(aws_cloudtrail.organization) == 1
    error_message = "Manual mode should plan exactly one organization trail."
  }

  assert {
    condition     = aws_cloudtrail.organization[0].is_organization_trail == true
    error_message = "Manual trail must be an organization trail."
  }

  assert {
    condition     = aws_cloudtrail.organization[0].enable_log_file_validation == true
    error_message = "Log file validation must be enabled."
  }
}

run "reject_manual_mode_when_control_tower_enabled" {
  command = plan

  variables {
    manual_mode_enabled   = true
    control_tower_enabled = true
    trail_name            = "duplicate-trail"
    s3_bucket_name        = "example-control-tower-log-archive"
    kms_key_arn           = "arn:aws:kms:eu-west-1:111111111111:key/11111111-1111-1111-1111-111111111111"
    tags = {
      Project     = "multi-account-landing-zone"
      Environment = "management"
      Owner       = "platform-team"
      ManagedBy   = "terraform"
      CostCenter  = "test"
    }
  }

  assert {
    condition     = length(aws_cloudtrail.organization) == 0
    error_message = "Control Tower enabled mode must not create a duplicate trail."
  }
}
