variable "role_definitions" {
  description = "Role definitions keyed by one of the supported canonical role names."
  type = map(object({
    description                       = string
    principal_type                    = string
    trusted_aws_principal_arns        = optional(set(string), [])
    require_mfa                       = bool
    max_session_duration              = optional(number, 3600)
    managed_policy_arns               = optional(set(string), [])
    inline_policy_json                = optional(string)
    permissions_boundary_arn_override = optional(string)
    oidc = optional(object({
      provider_arn = string
      issuer       = string
      audiences    = set(string)
      subjects     = set(string)
    }))
  }))

  validation {
    condition = length(setsubtract(toset(keys(var.role_definitions)), toset([
      "OrganizationAdminRole",
      "SecurityAuditRole",
      "NetworkAdminRole",
      "TerraformExecutionRole",
      "ReadOnlyRole",
      "IncidentResponseRole",
      "BreakGlassAdminRole",
      "AFTExecutionRole",
    ]))) == 0
    error_message = "role_definitions contains an unsupported role name."
  }

  validation {
    condition = alltrue([
      for role in values(var.role_definitions) : contains(["human", "automation"], role.principal_type)
    ])
    error_message = "principal_type must be human or automation."
  }

  validation {
    condition = alltrue([
      for role in values(var.role_definitions) :
      (role.principal_type == "human" && role.require_mfa) ||
      (role.principal_type == "automation" && !role.require_mfa)
    ])
    error_message = "Human assumptions must require MFA; automation assumptions must not require MFA."
  }

  validation {
    condition = alltrue([
      for role in values(var.role_definitions) :
      length(role.trusted_aws_principal_arns) > 0 || role.oidc != null
    ])
    error_message = "Every role must have at least one explicit AWS principal ARN or an explicit OIDC trust."
  }

  validation {
    condition = alltrue(flatten([
      for role in values(var.role_definitions) : [
        for arn in role.trusted_aws_principal_arns :
        can(regex("^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_/-]+$", arn)) && !strcontains(arn, "*")
      ]
    ]))
    error_message = "Trusted AWS principals must be exact IAM role ARNs; wildcards, account-root principals, users, and assumed-role session ARNs are rejected."
  }

  validation {
    condition = alltrue([
      for role in values(var.role_definitions) : role.oidc == null ? true : (
        can(regex("^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:oidc-provider/[A-Za-z0-9._:/-]+$", role.oidc.provider_arn)) &&
        !strcontains(role.oidc.provider_arn, "*") &&
        length(role.oidc.issuer) > 0 &&
        !startswith(role.oidc.issuer, "https://") &&
        !strcontains(role.oidc.issuer, "*") &&
        length(role.oidc.audiences) > 0 &&
        length(role.oidc.subjects) > 0 &&
        alltrue([for value in setunion(role.oidc.audiences, role.oidc.subjects) : length(value) > 0 && !strcontains(value, "*")])
      )
    ])
    error_message = "OIDC trust requires an exact provider ARN, issuer without scheme, and non-wildcard audience and subject values."
  }

  validation {
    condition = alltrue([
      for name, role in var.role_definitions :
      name == "TerraformExecutionRole" ? role.principal_type == "automation" && role.oidc != null : true
    ])
    error_message = "TerraformExecutionRole must be an automation role with explicit OIDC trust."
  }

  validation {
    condition = alltrue([
      for name, role in var.role_definitions :
      name == "AFTExecutionRole" ? role.principal_type == "automation" && role.oidc == null : true
    ])
    error_message = "AFTExecutionRole must be an automation role trusted by explicit AWS role ARNs, not a human or direct OIDC role."
  }

  validation {
    condition = alltrue([
      for role in values(var.role_definitions) :
      length(role.managed_policy_arns) > 0 || role.inline_policy_json != null
    ])
    error_message = "Every role requires at least one managed or inline permissions policy."
  }

  validation {
    condition = alltrue(flatten([
      for role in values(var.role_definitions) : [
        for arn in role.managed_policy_arns :
        can(regex("^arn:(aws|aws-us-gov|aws-cn):iam::(aws|[0-9]{12}):policy/[A-Za-z0-9+=,.@_/-]+$", arn)) && !strcontains(arn, "*")
      ]
    ]))
    error_message = "Managed policy ARNs must be exact IAM policy ARNs without wildcards."
  }

  validation {
    condition = alltrue([
      for role in values(var.role_definitions) : role.inline_policy_json == null ? true : (
        can(jsondecode(role.inline_policy_json)) &&
        try(jsondecode(role.inline_policy_json).Version, "") == "2012-10-17" &&
        can(jsondecode(role.inline_policy_json).Statement)
      )
    ])
    error_message = "Each inline policy must be valid IAM JSON with Version 2012-10-17 and a Statement member."
  }

  validation {
    condition = alltrue([
      for role in values(var.role_definitions) :
      role.max_session_duration >= 3600 && role.max_session_duration <= 43200
    ])
    error_message = "max_session_duration must be between 3600 and 43200 seconds."
  }

  validation {
    condition = alltrue([
      for role in values(var.role_definitions) : role.permissions_boundary_arn_override == null ? true : (
        can(regex("^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:policy/[A-Za-z0-9+=,.@_/-]+$", role.permissions_boundary_arn_override)) &&
        !strcontains(role.permissions_boundary_arn_override, "*")
      )
    ])
    error_message = "Each boundary override must be an exact customer-managed IAM policy ARN."
  }
}

variable "enable_aft" {
  description = "Whether AFT is approved. AFTExecutionRole is rejected unless true and required when true."
  type        = bool
  default     = false

  validation {
    condition     = var.enable_aft == contains(keys(var.role_definitions), "AFTExecutionRole")
    error_message = "AFTExecutionRole must exist exactly when enable_aft is true."
  }
}

variable "role_path" {
  description = "IAM path for all roles."
  type        = string
  default     = "/landing-zone/"

  validation {
    condition     = can(regex("^/([A-Za-z0-9+=,.@_-]+/)*$", var.role_path))
    error_message = "role_path must be a valid IAM path that begins and ends with a slash."
  }
}

variable "permissions_boundary_arn" {
  description = "Default permissions boundary ARN applied to every role; individual definitions may override it."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = var.permissions_boundary_arn == null ? true : (
      can(regex("^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:policy/[A-Za-z0-9+=,.@_/-]+$", var.permissions_boundary_arn)) &&
      !strcontains(var.permissions_boundary_arn, "*")
    )
    error_message = "permissions_boundary_arn must be an exact customer-managed IAM policy ARN."
  }
}

variable "tags" {
  description = "Tags applied to IAM roles."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["Project", "Environment", "Owner", "ManagedBy", "CostCenter"] :
      contains(keys(var.tags), key) && length(trimspace(var.tags[key])) > 0
    ])
    error_message = "tags must contain non-empty Project, Environment, Owner, ManagedBy, and CostCenter values."
  }
}
