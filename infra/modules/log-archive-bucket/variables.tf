variable "create_bucket" {
  description = "Create a Terraform-owned log bucket. Keep false when the target is a Control Tower-owned Log Archive bucket."
  type        = bool
  default     = false
}

variable "aws_partition" {
  description = "AWS partition used to construct IAM, KMS, S3, CloudTrail, and Logs ARNs."
  type        = string
  default     = "aws"

  validation {
    condition     = contains(["aws", "aws-us-gov", "aws-cn"], var.aws_partition)
    error_message = "aws_partition must be aws, aws-us-gov, or aws-cn."
  }
}

variable "current_account_id" {
  description = "Account ID where Terraform-owned KMS key administration is rooted. Required when create_kms_key=true."
  type        = string
  default     = null

  validation {
    condition     = var.current_account_id == null || can(regex("^[0-9]{12}$", var.current_account_id))
    error_message = "current_account_id must be a 12-digit AWS account ID."
  }
}

variable "control_tower_owned_bucket" {
  description = "Set true when the bucket is owned by AWS Control Tower. This module refuses to manage that bucket."
  type        = bool
  default     = true
}

variable "bucket_name" {
  description = "Globally unique name for a Terraform-owned log archive or extension bucket."
  type        = string
  default     = null

  validation {
    condition     = var.bucket_name == null || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be a valid S3 bucket name when provided."
  }
}

variable "force_destroy" {
  description = "Whether to allow Terraform to destroy a non-empty bucket. Must remain false for log archives except disposable tests."
  type        = bool
  default     = false
}

variable "create_kms_key" {
  description = "Create a Terraform-owned KMS key for this Terraform-owned bucket."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "Existing customer-managed KMS key ARN for bucket default encryption. Required when create_bucket=true and create_kms_key=false."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:(aws|aws-us-gov|aws-cn):kms:[a-z0-9-]+:[0-9]{12}:key/[A-Za-z0-9-]+$", var.kms_key_arn))
    error_message = "kms_key_arn must be an exact KMS key ARN."
  }
}

variable "kms_key_alias" {
  description = "Optional alias name for a Terraform-owned KMS key, without the alias/ prefix."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_alias == null || can(regex("^[A-Za-z0-9/_-]+$", var.kms_key_alias))
    error_message = "kms_key_alias must contain only letters, numbers, slash, underscore, or hyphen."
  }
}

variable "kms_administrator_role_arns" {
  description = "Exact role ARNs allowed to administer a Terraform-owned KMS key."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.kms_administrator_role_arns :
      can(regex("^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_/-]+$", arn)) && !strcontains(arn, "*")
    ])
    error_message = "KMS administrator principals must be exact IAM role ARNs without wildcards."
  }
}

variable "log_reader_role_arns" {
  description = "Exact role ARNs allowed to read objects and decrypt logs."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.log_reader_role_arns :
      can(regex("^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_/-]+$", arn)) && !strcontains(arn, "*")
    ])
    error_message = "Log reader principals must be exact IAM role ARNs without wildcards."
  }
}

variable "cloudtrail_source_arns" {
  description = "Exact CloudTrail trail ARNs allowed to deliver to this Terraform-owned bucket."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.cloudtrail_source_arns :
      can(regex("^arn:(aws|aws-us-gov|aws-cn):cloudtrail:[a-z0-9-]+:[0-9]{12}:trail/[A-Za-z0-9._+=,@-]+$", arn)) && !strcontains(arn, "*")
    ])
    error_message = "CloudTrail source ARNs must be exact trail ARNs without wildcards."
  }
}

variable "cloudtrail_log_prefix" {
  description = "Optional S3 prefix for CloudTrail logs."
  type        = string
  default     = "cloudtrail"

  validation {
    condition     = can(regex("^[A-Za-z0-9!_.*'()/=-]*$", var.cloudtrail_log_prefix)) && !startswith(var.cloudtrail_log_prefix, "/")
    error_message = "cloudtrail_log_prefix must be an S3 key prefix without a leading slash."
  }
}

variable "flow_log_sources" {
  description = "VPC Flow Log source accounts and Regions allowed to deliver to this Terraform-owned bucket."
  type = map(object({
    account_id = string
    regions    = set(string)
    prefix     = optional(string, "vpc-flow-logs")
  }))
  default = {}

  validation {
    condition = alltrue([
      for source in values(var.flow_log_sources) :
      can(regex("^[0-9]{12}$", source.account_id)) &&
      alltrue([for region in source.regions : can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", region))])
    ])
    error_message = "Each flow log source must include a 12-digit account_id and valid Region identifiers."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Days to retain noncurrent object versions for recoverability."
  type        = number
  default     = 365

  validation {
    condition     = var.noncurrent_version_expiration_days >= 90
    error_message = "Retain noncurrent log versions for at least 90 days."
  }
}

variable "transition_to_ia_days" {
  description = "Days before transitioning logs to STANDARD_IA. Set null to disable."
  type        = number
  default     = 90
}

variable "transition_to_glacier_days" {
  description = "Days before transitioning logs to GLACIER. Set null to disable."
  type        = number
  default     = 365
}

variable "expiration_days" {
  description = "Optional object expiration days. Null preserves logs indefinitely subject to storage-class transitions."
  type        = number
  default     = null

  validation {
    condition     = coalesce(var.expiration_days, 365) >= 365
    error_message = "Log expiration must be null or at least 365 days."
  }
}

variable "object_lock_enabled" {
  description = "Enable Object Lock at bucket creation. This is a separately approved design decision and cannot be enabled later on an existing bucket by this module."
  type        = bool
  default     = false
}

variable "object_lock_approval" {
  description = "Required acknowledgement when object_lock_enabled=true."
  type        = string
  default     = ""

  validation {
    condition     = !var.object_lock_enabled || var.object_lock_approval == "I approve Object Lock for this Terraform-owned log archive bucket"
    error_message = "Object Lock requires the exact approval acknowledgement."
  }
}

variable "tags" {
  description = "Tags applied to Terraform-owned logging resources."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["Project", "Environment", "Owner", "ManagedBy", "CostCenter"] :
      contains(keys(var.tags), key) && length(trimspace(var.tags[key])) > 0
    ])
    error_message = "tags must contain non-empty Project, Environment, Owner, ManagedBy, and CostCenter values."
  }
}
