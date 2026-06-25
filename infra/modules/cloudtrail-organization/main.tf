locals {
  create_manual_trail = var.manual_mode_enabled && !var.control_tower_enabled
}

resource "aws_cloudtrail" "organization" {
  count = local.create_manual_trail ? 1 : 0

  name                          = var.trail_name
  s3_bucket_name                = var.s3_bucket_name
  s3_key_prefix                 = var.s3_key_prefix
  kms_key_id                    = var.kms_key_arn
  enable_log_file_validation    = var.enable_log_file_validation
  include_global_service_events = var.include_global_service_events
  is_multi_region_trail         = var.is_multi_region_trail
  is_organization_trail         = true
  cloud_watch_logs_group_arn    = var.cloudwatch_logs_group_arn
  cloud_watch_logs_role_arn     = var.cloudwatch_logs_role_arn
  sns_topic_name                = var.sns_topic_name
  tags                          = var.tags

  event_selector {
    read_write_type           = var.read_write_type
    include_management_events = var.enable_management_events
    exclude_management_event_sources = (
      length(var.exclude_management_event_sources) > 0 ?
      sort(tolist(var.exclude_management_event_sources)) :
      null
    )

    dynamic "data_resource" {
      for_each = var.enable_s3_data_events ? [1] : []
      content {
        type   = "AWS::S3::Object"
        values = sort(tolist(var.s3_data_event_arns))
      }
    }
  }

  lifecycle {
    precondition {
      condition     = !var.control_tower_enabled
      error_message = "Do not create a Terraform organization trail when AWS Control Tower owns centralized logging."
    }

    precondition {
      condition     = var.trail_name != null && var.s3_bucket_name != null && var.kms_key_arn != null
      error_message = "trail_name, s3_bucket_name, and kms_key_arn are required in manual mode."
    }

    precondition {
      condition     = var.enable_log_file_validation
      error_message = "Organization trails must keep log file validation enabled."
    }

    precondition {
      condition     = !var.enable_s3_data_events || length(var.s3_data_event_arns) > 0
      error_message = "S3 data events require explicit s3_data_event_arns and cost approval."
    }
  }
}
