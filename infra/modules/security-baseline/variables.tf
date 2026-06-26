variable "deployment_scope" {
  description = "Deployment scope for this plan: management-delegation, security-regional, or member-account."
  type        = string
  default     = "security-regional"

  validation {
    condition     = contains(["management-delegation", "security-regional", "member-account"], var.deployment_scope)
    error_message = "deployment_scope must be management-delegation, security-regional, or member-account."
  }
}

variable "approved_regions" {
  description = "Explicit approved Regions where the security baseline may be planned."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for region in var.approved_regions : can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", region))
    ])
    error_message = "approved_regions must contain valid AWS Region identifiers."
  }
}

variable "aws_region" {
  description = "Current provider Region for this separately generated regional plan."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must be a valid AWS Region identifier."
  }
}

variable "current_account_id" {
  description = "Expected caller account ID for this plan."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.current_account_id))
    error_message = "current_account_id must be a 12-digit AWS account ID."
  }
}

variable "management_account_id" {
  description = "AWS Organizations management account ID."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "management_account_id must be a 12-digit AWS account ID."
  }
}

variable "security_account_id" {
  description = "Delegated security administrator account ID."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.security_account_id))
    error_message = "security_account_id must be a 12-digit AWS account ID."
  }
}

variable "cost_approval" {
  description = "Required acknowledgement before enabling paid security services."
  type        = string
  default     = ""
}

variable "control_tower_manages_config" {
  description = "Whether AWS Control Tower owns Config recorder/delivery resources in governed accounts."
  type        = bool
  default     = true
}

variable "enable_guardduty_delegated_admin" {
  description = "Designate the security account as GuardDuty delegated administrator in this Region."
  type        = bool
  default     = false
}

variable "enable_guardduty" {
  description = "Enable GuardDuty detector in the security account for this Region."
  type        = bool
  default     = false
}

variable "guardduty_auto_enable_organization_members" {
  description = "GuardDuty organization auto-enable mode."
  type        = string
  default     = "NEW"

  validation {
    condition     = contains(["NONE", "NEW", "ALL"], var.guardduty_auto_enable_organization_members)
    error_message = "guardduty_auto_enable_organization_members must be NONE, NEW, or ALL."
  }
}

variable "enable_securityhub_delegated_admin" {
  description = "Designate the security account as Security Hub delegated administrator in this Region."
  type        = bool
  default     = false
}

variable "enable_securityhub" {
  description = "Enable Security Hub in the security account for this Region."
  type        = bool
  default     = false
}

variable "securityhub_auto_enable" {
  description = "Automatically enable Security Hub for new organization accounts."
  type        = bool
  default     = false
}

variable "securityhub_auto_enable_standards" {
  description = "Security Hub standards auto-enable setting."
  type        = string
  default     = "NONE"

  validation {
    condition     = contains(["NONE", "DEFAULT"], var.securityhub_auto_enable_standards)
    error_message = "securityhub_auto_enable_standards must be NONE or DEFAULT."
  }
}

variable "enable_securityhub_finding_aggregator" {
  description = "Create a Security Hub finding aggregator in the security account."
  type        = bool
  default     = false
}

variable "securityhub_finding_aggregation_regions" {
  description = "Regions linked to the Security Hub finding aggregator when using SPECIFIED_REGIONS."
  type        = set(string)
  default     = []
}

variable "enable_access_analyzer" {
  description = "Create an organization-scoped IAM Access Analyzer in the security account."
  type        = bool
  default     = false
}

variable "enable_access_analyzer_delegated_admin" {
  description = "Register the security account as delegated administrator for IAM Access Analyzer from the management account."
  type        = bool
  default     = false
}

variable "access_analyzer_name" {
  description = "Name of the organization Access Analyzer."
  type        = string
  default     = "organization-external-access"
}

variable "enable_config_aggregator" {
  description = "Create an AWS Config organization aggregator in the security account. Does not create recorders or delivery channels."
  type        = bool
  default     = false
}

variable "config_aggregator_name" {
  description = "Name for the AWS Config organization aggregator."
  type        = string
  default     = "organization-config-aggregator"
}

variable "config_aggregator_role_arn" {
  description = "IAM role ARN used by AWS Config organization aggregator."
  type        = string
  default     = null

  validation {
    condition     = var.config_aggregator_role_arn == null || can(regex("^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_/-]+$", var.config_aggregator_role_arn))
    error_message = "config_aggregator_role_arn must be an exact IAM role ARN."
  }
}

variable "enable_s3_account_public_access_block" {
  description = "Enable account-level S3 Block Public Access in the current account."
  type        = bool
  default     = false
}

variable "enable_inspector_delegated_admin" {
  description = "Designate the security account as Inspector delegated administrator in this Region."
  type        = bool
  default     = false
}

variable "enable_inspector" {
  description = "Enable Inspector in this account/Region."
  type        = bool
  default     = false
}

variable "inspector_resource_types" {
  description = "Inspector resource types to enable."
  type        = set(string)
  default     = ["EC2", "ECR", "LAMBDA"]

  validation {
    condition = alltrue([
      for resource_type in var.inspector_resource_types : contains(["EC2", "ECR", "LAMBDA", "LAMBDA_CODE", "CODE_REPOSITORY"], resource_type)
    ])
    error_message = "Inspector resource types must be EC2, ECR, LAMBDA, LAMBDA_CODE, or CODE_REPOSITORY."
  }
}

variable "enable_macie_delegated_admin" {
  description = "Designate the security account as Macie delegated administrator in this Region."
  type        = bool
  default     = false
}

variable "enable_macie" {
  description = "Enable Macie in this account/Region."
  type        = bool
  default     = false
}

variable "macie_finding_publishing_frequency" {
  description = "Macie finding publishing frequency."
  type        = string
  default     = "FIFTEEN_MINUTES"

  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.macie_finding_publishing_frequency)
    error_message = "macie_finding_publishing_frequency must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

variable "alert_target_arn" {
  description = "Optional SNS topic, EventBridge bus, or other EventBridge target ARN for high/critical findings."
  type        = string
  default     = null

  validation {
    condition     = var.alert_target_arn == null || can(regex("^arn:(aws|aws-us-gov|aws-cn):[A-Za-z0-9-]+:[a-z0-9-]*:[0-9]{0,12}:.+$", var.alert_target_arn))
    error_message = "alert_target_arn must be an exact ARN when provided."
  }
}

variable "alert_event_bus_name" {
  description = "EventBridge event bus name for alert rules."
  type        = string
  default     = "default"
}

variable "enable_alert_routing" {
  description = "Create EventBridge rules that route high/critical findings to alert_target_arn."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to supported security baseline resources."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["Project", "Environment", "Owner", "ManagedBy", "CostCenter"] :
      contains(keys(var.tags), key) && length(trimspace(var.tags[key])) > 0
    ])
    error_message = "tags must contain non-empty Project, Environment, Owner, ManagedBy, and CostCenter values."
  }
}
