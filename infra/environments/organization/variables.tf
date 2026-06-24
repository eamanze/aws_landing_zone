variable "aws_region" {
  description = "Control Tower home Region used for AWS provider operations."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must be a valid AWS Region identifier."
  }
}

variable "project_name" {
  description = "Required Project tag value."
  type        = string
  default     = "multi-account-landing-zone"
}

variable "expected_organization_id" {
  description = "Expected AWS Organizations ID."
  type        = string

  validation {
    condition     = can(regex("^o-[a-z0-9]{10,32}$", var.expected_organization_id))
    error_message = "expected_organization_id must look like o- followed by 10-32 lowercase letters or digits."
  }
}

variable "expected_management_account_id" {
  description = "Expected 12-digit management account ID and permitted AWS provider caller account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_management_account_id))
    error_message = "expected_management_account_id must be a 12-digit AWS account ID."
  }
}

variable "organization_root_id" {
  description = "Existing Organizations root ID under which the target OUs already exist."
  type        = string

  validation {
    condition     = can(regex("^r-[a-z0-9]{4,32}$", var.organization_root_id))
    error_message = "organization_root_id must be a valid Organizations root ID."
  }
}

variable "ou_names" {
  description = "Canonical OU key-to-name map. All five OUs must already exist directly below the root."
  type        = map(string)
  default = {
    security       = "Security"
    infrastructure = "Infrastructure"
    non_production = "Non-Production"
    production     = "Production"
    sandbox        = "Sandbox"
  }
}

variable "account_registry" {
  description = "Existing Control Tower-vended member accounts. Account IDs belong only in ignored local configuration or an approved secret store."
  type = map(object({
    account_id   = string
    account_name = string
    ou_key       = string
    owner        = string
    environment  = string
    cost_center  = string
    managed_by   = string
    tags         = optional(map(string), {})
  }))

  validation {
    condition = alltrue([
      for account in values(var.account_registry) : can(regex("^[0-9]{12}$", account.account_id))
    ])
    error_message = "Every account_id must be a 12-digit AWS account ID."
  }

  validation {
    condition = alltrue([
      for account in values(var.account_registry) :
      length(trimspace(account.account_name)) > 0 &&
      length(trimspace(account.owner)) > 0 &&
      length(trimspace(account.environment)) > 0 &&
      length(trimspace(account.cost_center)) > 0 &&
      length(trimspace(account.managed_by)) > 0
    ])
    error_message = "Every account requires a non-empty name, owner, environment, cost center, and managed-by value."
  }
}
