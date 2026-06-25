variable "manual_mode_enabled" {
  description = "Create a Terraform-owned organization trail only for manual AWS Organizations mode. Keep false for Control Tower-first deployments."
  type        = bool
  default     = false
}

variable "control_tower_enabled" {
  description = "Whether AWS Control Tower owns the landing-zone logging baseline. When true, this module creates no trail and rejects manual_mode_enabled=true."
  type        = bool
  default     = true
}

variable "trail_name" {
  description = "Name of the Terraform-owned organization trail in manual mode."
  type        = string
  default     = null

  validation {
    condition     = var.trail_name == null || can(regex("^[A-Za-z0-9._-]{3,128}$", var.trail_name))
    error_message = "trail_name must be 3-128 characters and contain letters, numbers, dots, underscores, or hyphens."
  }
}

variable "s3_bucket_name" {
  description = "Terraform-owned destination bucket name for the manual-mode organization trail."
  type        = string
  default     = null
}

variable "s3_key_prefix" {
  description = "Optional S3 key prefix for CloudTrail logs."
  type        = string
  default     = "cloudtrail"

  validation {
    condition     = can(regex("^[A-Za-z0-9!_.*'()/=-]*$", var.s3_key_prefix)) && !startswith(var.s3_key_prefix, "/")
    error_message = "s3_key_prefix must be an S3 key prefix without a leading slash."
  }
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key ARN for CloudTrail SSE-KMS encryption."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:(aws|aws-us-gov|aws-cn):kms:[a-z0-9-]+:[0-9]{12}:key/[A-Za-z0-9-]+$", var.kms_key_arn))
    error_message = "kms_key_arn must be an exact KMS key ARN."
  }
}

variable "enable_log_file_validation" {
  description = "Enable CloudTrail log file integrity validation."
  type        = bool
  default     = true
}

variable "include_global_service_events" {
  description = "Whether the trail logs global service events such as IAM."
  type        = bool
  default     = true
}

variable "is_multi_region_trail" {
  description = "Whether the manual-mode organization trail applies to all Regions."
  type        = bool
  default     = true
}

variable "enable_management_events" {
  description = "Whether to log management events."
  type        = bool
  default     = true
}

variable "read_write_type" {
  description = "Management event selector read/write scope."
  type        = string
  default     = "All"

  validation {
    condition     = contains(["All", "ReadOnly", "WriteOnly"], var.read_write_type)
    error_message = "read_write_type must be All, ReadOnly, or WriteOnly."
  }
}

variable "exclude_management_event_sources" {
  description = "Management event sources to exclude, if explicitly approved."
  type        = set(string)
  default     = []
}

variable "enable_s3_data_events" {
  description = "Enable high-volume S3 data events. Requires separate cost approval."
  type        = bool
  default     = false
}

variable "s3_data_event_arns" {
  description = "S3 object ARNs for data event logging when enable_s3_data_events=true."
  type        = set(string)
  default     = []
}

variable "cloudwatch_logs_group_arn" {
  description = "Optional CloudWatch Logs group ARN for CloudTrail delivery."
  type        = string
  default     = null
}

variable "cloudwatch_logs_role_arn" {
  description = "Optional CloudWatch Logs role ARN for CloudTrail delivery."
  type        = string
  default     = null
}

variable "sns_topic_name" {
  description = "Optional SNS topic name for CloudTrail delivery notifications."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the Terraform-owned organization trail."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["Project", "Environment", "Owner", "ManagedBy", "CostCenter"] :
      contains(keys(var.tags), key) && length(trimspace(var.tags[key])) > 0
    ])
    error_message = "tags must contain non-empty Project, Environment, Owner, ManagedBy, and CostCenter values."
  }
}
