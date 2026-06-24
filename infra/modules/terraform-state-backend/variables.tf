variable "bucket_name_prefix" {
  description = "Lowercase prefix used with the caller account ID and AWS Region to form a globally unique bucket name."
  type        = string
  default     = "aws-landing-zone-tfstate"

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{1,28}[a-z0-9])$", var.bucket_name_prefix))
    error_message = "bucket_name_prefix must be 3-30 lowercase letters, numbers, or hyphens and cannot start or end with a hyphen."
  }
}

variable "bucket_administrator_arns" {
  description = "Existing IAM role/user ARNs allowed to administer the state bucket. Do not pass STS session ARNs."
  type        = set(string)

  validation {
    condition     = length(var.bucket_administrator_arns) > 0
    error_message = "At least one existing bucket administrator ARN is required to avoid an unrecoverable bucket policy."
  }

  validation {
    condition = alltrue([
      for arn in var.bucket_administrator_arns :
      can(regex("^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:(role/.+|user/.+)$", arn))
    ])
    error_message = "Bucket administrators must be IAM role or user ARNs, not account IDs, wildcards, or STS session ARNs."
  }
}

variable "kms_administrator_arns" {
  description = "Existing IAM role/user ARNs allowed to administer the customer-managed KMS key."
  type        = set(string)

  validation {
    condition     = length(var.kms_administrator_arns) > 0
    error_message = "At least one existing KMS administrator ARN is required."
  }

  validation {
    condition = alltrue([
      for arn in var.kms_administrator_arns :
      can(regex("^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:(role/.+|user/.+)$", arn))
    ])
    error_message = "KMS administrators must be IAM role or user ARNs, not account IDs, wildcards, or STS session ARNs."
  }
}

variable "state_access_principals" {
  description = "Named IAM principals and the state-key prefixes each principal may access. Prefixes must not begin or end with a slash."
  type = map(object({
    principal_arn      = string
    state_key_prefixes = set(string)
  }))

  validation {
    condition     = length(var.state_access_principals) > 0
    error_message = "At least one state access principal is required."
  }

  validation {
    condition = alltrue([
      for access in values(var.state_access_principals) :
      can(regex("^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:(role/.+|user/.+)$", access.principal_arn))
    ])
    error_message = "State access principals must be IAM role or user ARNs, not wildcards or STS session ARNs."
  }

  validation {
    condition = alltrue(flatten([
      for access in values(var.state_access_principals) : [
        for prefix in access.state_key_prefixes :
        can(regex("^[a-z0-9][a-z0-9/_-]*[a-z0-9]$", prefix)) && !startswith(prefix, "/") && !endswith(prefix, "/")
      ]
    ]))
    error_message = "State key prefixes must contain lowercase letters, numbers, slash, underscore, or hyphen and cannot begin or end with a slash."
  }

  validation {
    condition = alltrue([
      for access in values(var.state_access_principals) : length(access.state_key_prefixes) > 0
    ])
    error_message = "Every state access principal must have at least one state-key prefix."
  }
}

variable "noncurrent_version_transition_days" {
  description = "Days before noncurrent state versions transition to S3 Standard-IA."
  type        = number
  default     = 30

  validation {
    condition     = var.noncurrent_version_transition_days >= 30
    error_message = "Standard-IA transition must be at least 30 days."
  }
}

variable "noncurrent_version_archive_days" {
  description = "Days before noncurrent state versions transition to S3 Glacier Flexible Retrieval."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_archive_days > var.noncurrent_version_transition_days
    error_message = "Archive transition must occur after the Standard-IA transition."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Days before noncurrent state versions expire. Current state objects are never expired by lifecycle."
  type        = number
  default     = 365

  validation {
    condition     = var.noncurrent_version_expiration_days > var.noncurrent_version_archive_days
    error_message = "Noncurrent version expiration must occur after the archive transition."
  }
}

variable "kms_deletion_window_days" {
  description = "KMS key deletion waiting period. Destruction is also blocked by prevent_destroy."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_days >= 7 && var.kms_deletion_window_days <= 30
    error_message = "kms_deletion_window_days must be between 7 and 30."
  }
}

variable "project_name" {
  description = "Project tag value."
  type        = string
  default     = "multi-account-landing-zone"

  validation {
    condition     = length(trimspace(var.project_name)) > 0
    error_message = "project_name cannot be empty."
  }
}

variable "owner" {
  description = "Accountable owner tag value."
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner cannot be empty."
  }
}

variable "cost_center" {
  description = "Approved cost-center tag value."
  type        = string

  validation {
    condition     = length(trimspace(var.cost_center)) > 0
    error_message = "cost_center cannot be empty."
  }
}

variable "additional_tags" {
  description = "Additional tags. Required baseline tags take precedence."
  type        = map(string)
  default     = {}
}
