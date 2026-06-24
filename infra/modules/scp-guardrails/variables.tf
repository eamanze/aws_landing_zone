variable "aws_partition" {
  description = "AWS partition used to construct Control Tower role patterns and IAM resource ARNs."
  type        = string
  default     = "aws"

  validation {
    condition     = contains(["aws", "aws-us-gov", "aws-cn"], var.aws_partition)
    error_message = "aws_partition must be aws, aws-us-gov, or aws-cn."
  }
}

variable "target_ou_ids" {
  description = "Existing child OU IDs. Root IDs and account IDs are structurally rejected."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for id in var.target_ou_ids : can(regex("^ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}$", id))
    ])
    error_message = "Every target must be a child OU ID beginning with ou-. Root and account attachment are not supported."
  }
}

variable "approved_exception_role_arns" {
  description = "Exact approved role ARNs exempted from conditional custom controls. Keep this list minimal; AWSControlTowerExecution is added separately."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.approved_exception_role_arns :
      can(regex("^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_/-]+$", arn)) && !strcontains(arn, "*")
    ])
    error_message = "Exception principals must be exact IAM role ARNs without wildcards."
  }
}

variable "attach_deny_leave_organization" {
  description = "Attach the deny-leaving-organization SCP to target_ou_ids."
  type        = bool
  default     = false
}

variable "attach_protect_security_services" {
  description = "Attach the GuardDuty, Security Hub CSPM, and Access Analyzer protection SCP to target_ou_ids."
  type        = bool
  default     = false
}

variable "attach_restrict_iam_users" {
  description = "Attach the IAM-user and long-lived-credential restriction SCP to target_ou_ids."
  type        = bool
  default     = false
}

variable "attach_restrict_privilege_escalation" {
  description = "Attach the high-risk IAM privilege-escalation restriction SCP to target_ou_ids."
  type        = bool
  default     = false
}

variable "attach_restrict_s3_public_access" {
  description = "Attach the S3 public ACL and Block Public Access tamper restriction SCP to target_ou_ids."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to custom Organizations policies."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["Project", "Environment", "Owner", "ManagedBy", "CostCenter"] :
      contains(keys(var.tags), key) && length(trimspace(var.tags[key])) > 0
    ])
    error_message = "tags must contain non-empty Project, Environment, Owner, ManagedBy, and CostCenter values."
  }
}
