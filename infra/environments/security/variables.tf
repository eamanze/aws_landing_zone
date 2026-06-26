variable "deployment_scope" {
  description = "Plan one scope at a time: management-delegation, security-regional, or member-account."
  type        = string
  default     = "security-regional"
}

variable "aws_region" {
  description = "Single approved Region for this plan."
  type        = string
}

variable "approved_regions" {
  description = "Approved Regions for the security baseline."
  type        = set(string)
}

variable "current_account_id" {
  description = "Expected caller account ID for this plan."
  type        = string
}

variable "management_account_id" {
  description = "Management account ID."
  type        = string
}

variable "security_account_id" {
  description = "Security account ID."
  type        = string
}

variable "cost_approval" {
  description = "Exact approval string required before paid service enablement."
  type        = string
  default     = ""
}

variable "control_tower_manages_config" {
  description = "True while Control Tower owns Config recorder/delivery resources."
  type        = bool
  default     = true
}

variable "enable_guardduty_delegated_admin" {
  type    = bool
  default = false
}

variable "enable_guardduty" {
  type    = bool
  default = false
}

variable "enable_securityhub_delegated_admin" {
  type    = bool
  default = false
}

variable "enable_securityhub" {
  type    = bool
  default = false
}

variable "enable_securityhub_finding_aggregator" {
  type    = bool
  default = false
}

variable "securityhub_finding_aggregation_regions" {
  type    = set(string)
  default = []
}

variable "enable_access_analyzer" {
  type    = bool
  default = false
}

variable "enable_access_analyzer_delegated_admin" {
  type    = bool
  default = false
}

variable "enable_config_aggregator" {
  type    = bool
  default = false
}

variable "config_aggregator_role_arn" {
  type    = string
  default = null
}

variable "enable_s3_account_public_access_block" {
  type    = bool
  default = false
}

variable "enable_inspector_delegated_admin" {
  type    = bool
  default = false
}

variable "enable_inspector" {
  type    = bool
  default = false
}

variable "enable_macie_delegated_admin" {
  type    = bool
  default = false
}

variable "enable_macie" {
  type    = bool
  default = false
}

variable "enable_alert_routing" {
  type    = bool
  default = false
}

variable "alert_target_arn" {
  type    = string
  default = null
}

variable "tags" {
  description = "Required tags."
  type        = map(string)
}
