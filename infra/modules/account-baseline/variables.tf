variable "account_type" {
  description = "Landing-zone account classification used for validation and tags."
  type        = string

  validation {
    condition = contains([
      "management",
      "security",
      "log-archive",
      "shared-services",
      "development",
      "staging",
      "production",
      "sandbox",
      "aft",
    ], var.account_type)
    error_message = "account_type is not a supported landing-zone account classification."
  }
}

variable "aws_partition" {
  description = "AWS partition used to construct AWS-managed policy ARNs."
  type        = string
  default     = "aws"

  validation {
    condition     = contains(["aws", "aws-us-gov", "aws-cn"], var.aws_partition)
    error_message = "aws_partition must be aws, aws-us-gov, or aws-cn."
  }
}

variable "enabled_roles" {
  description = "Canonical roles to create in this account. Select only roles justified for the account type."
  type        = set(string)

  validation {
    condition = length(setsubtract(var.enabled_roles, toset([
      "OrganizationAdminRole",
      "SecurityAuditRole",
      "NetworkAdminRole",
      "TerraformExecutionRole",
      "ReadOnlyRole",
      "IncidentResponseRole",
      "BreakGlassAdminRole",
      "AFTExecutionRole",
    ]))) == 0
    error_message = "enabled_roles contains an unsupported canonical role name."
  }

  validation {
    condition     = var.enable_aft == contains(var.enabled_roles, "AFTExecutionRole")
    error_message = "AFTExecutionRole must be enabled exactly when enable_aft is true."
  }

  validation {
    condition     = !contains(var.enabled_roles, "OrganizationAdminRole") || var.account_type == "management"
    error_message = "OrganizationAdminRole may be created only in the management account baseline."
  }

  validation {
    condition     = !contains(var.enabled_roles, "TerraformExecutionRole") || var.terraform_oidc != null
    error_message = "TerraformExecutionRole requires terraform_oidc configuration."
  }

  validation {
    condition = !contains(var.enabled_roles, "BreakGlassAdminRole") || (
      var.break_glass_acknowledgement == "I acknowledge monitored emergency administrator access" &&
      var.break_glass_alert_target_arn != null
    )
    error_message = "BreakGlassAdminRole requires the exact acknowledgement and a monitoring target ARN."
  }
}

variable "enable_aft" {
  description = "Whether AFT has been approved for this landing zone."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_aft || var.account_type == "aft"
    error_message = "AFTExecutionRole is created only in the dedicated AFT account baseline."
  }
}

variable "human_trusted_principal_arns" {
  description = "Exact source IAM role ARNs keyed by enabled human role. Prefer Identity Center permission sets for routine human access."
  type        = map(set(string))
  default     = {}
}

variable "automation_trusted_principal_arns" {
  description = "Exact source IAM role ARNs keyed by enabled automation role, primarily AFTExecutionRole."
  type        = map(set(string))
  default     = {}
}

variable "terraform_oidc" {
  description = "Exact CI OIDC trust. Subjects should identify approved repository branches, tags, or protected environments."
  type = object({
    provider_arn = string
    issuer       = string
    audiences    = set(string)
    subjects     = set(string)
  })
  default  = null
  nullable = true
}

variable "additional_managed_policy_arns" {
  description = "Additional exact managed-policy ARNs keyed by role. Use customer-managed least-privilege policies for Terraform and AFT."
  type        = map(set(string))
  default     = {}
}

variable "inline_policy_overrides" {
  description = "Optional complete inline policy JSON replacements keyed by role. Overrides the module's limited default policy for that role."
  type        = map(string)
  default     = {}
}

variable "permissions_boundary_arn" {
  description = "Customer-managed permissions boundary applied to all roles."
  type        = string
  default     = null
  nullable    = true
}

variable "break_glass_acknowledgement" {
  description = "Required exact acknowledgement when BreakGlassAdminRole is enabled."
  type        = string
  default     = null
  nullable    = true
}

variable "break_glass_alert_target_arn" {
  description = "Existing SNS, SQS, Lambda, or other EventBridge-compatible target ARN for immediate break-glass alerts."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = var.break_glass_alert_target_arn == null ? true : (
      can(regex("^arn:(aws|aws-us-gov|aws-cn):[a-z0-9-]+:[a-z0-9-]*:[0-9]{0,12}:.+$", var.break_glass_alert_target_arn)) &&
      !strcontains(var.break_glass_alert_target_arn, "*")
    )
    error_message = "break_glass_alert_target_arn must be an exact ARN without wildcards."
  }
}

variable "break_glass_event_bus_name" {
  description = "EventBridge bus that receives CloudTrail AssumeRole events."
  type        = string
  default     = "default"
}

variable "role_path" {
  description = "IAM path for baseline roles."
  type        = string
  default     = "/landing-zone/"
}

variable "tags" {
  description = "Required landing-zone tags. Environment should identify the target account classification."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["Project", "Environment", "Owner", "ManagedBy", "CostCenter"] :
      contains(keys(var.tags), key) && length(trimspace(var.tags[key])) > 0
    ])
    error_message = "tags must contain non-empty Project, Environment, Owner, ManagedBy, and CostCenter values."
  }
}
