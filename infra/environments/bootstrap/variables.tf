variable "aws_region" {
  description = "AWS Region in which the Terraform state backend is created."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}(?:-gov)?-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must be a valid AWS Region identifier such as eu-west-1."
  }
}

variable "expected_account_id" {
  description = "Expected AWS account ID. The provider refuses to operate in any other account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must be a 12-digit AWS account ID."
  }
}

variable "acknowledge_local_state_risk" {
  description = "Must be true to acknowledge that bootstrap temporarily stores sensitive state locally until migration."
  type        = bool

  validation {
    condition     = var.acknowledge_local_state_risk
    error_message = "Set acknowledge_local_state_risk=true only after reviewing README.md and MIGRATION.md."
  }
}

variable "bucket_name_prefix" {
  description = "Validated prefix combined with account ID and Region by the backend module."
  type        = string
  default     = "aws-landing-zone-tfstate"

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{1,28}[a-z0-9])$", var.bucket_name_prefix))
    error_message = "bucket_name_prefix must be 3-30 lowercase letters, numbers, or hyphens and cannot start or end with a hyphen."
  }
}

variable "bucket_administrator_arns" {
  description = "Existing IAM role/user ARNs allowed to administer the state bucket."
  type        = set(string)
}

variable "kms_administrator_arns" {
  description = "Existing IAM role/user ARNs allowed to administer the state KMS key."
  type        = set(string)
}

variable "state_access_principals" {
  description = "Named state principals and their allowed state-key prefixes."
  type = map(object({
    principal_arn      = string
    state_key_prefixes = set(string)
  }))
}

variable "project_name" {
  description = "Project tag value."
  type        = string
  default     = "multi-account-landing-zone"
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

variable "noncurrent_version_transition_days" {
  description = "Days before noncurrent versions transition to Standard-IA."
  type        = number
  default     = 30
}

variable "noncurrent_version_archive_days" {
  description = "Days before noncurrent versions transition to Glacier Flexible Retrieval."
  type        = number
  default     = 90
}

variable "noncurrent_version_expiration_days" {
  description = "Days before noncurrent versions expire."
  type        = number
  default     = 365
}

variable "additional_tags" {
  description = "Additional tags passed to the backend module."
  type        = map(string)
  default     = {}
}
