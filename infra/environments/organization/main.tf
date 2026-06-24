locals {
  required_ou_keys = toset([
    "security",
    "infrastructure",
    "non_production",
    "production",
    "sandbox",
  ])

  required_account_keys = toset([
    "security",
    "log_archive",
    "shared_services",
    "development",
    "staging",
    "production",
  ])

  optional_account_keys = toset(["sandbox"])
  allowed_account_keys  = setunion(local.required_account_keys, local.optional_account_keys)

  expected_tags = {
    for key, account in var.account_registry : key => merge(account.tags, {
      Project     = var.project_name
      Environment = account.environment
      Owner       = account.owner
      CostCenter  = account.cost_center
      ManagedBy   = account.managed_by
    })
  }

  placement_results = {
    for key, account in var.account_registry : key => {
      account_id         = account.account_id
      account_name       = data.aws_organizations_account.registered[key].name
      expected_ou        = var.ou_names[account.ou_key]
      expected_parent_id = data.aws_organizations_organizational_unit.target[account.ou_key].id
      actual_parent_id   = data.aws_organizations_account.registered[key].parent_id
      account_state      = data.aws_organizations_account.registered[key].state
      name_matches       = data.aws_organizations_account.registered[key].name == account.account_name
      placement_matches  = data.aws_organizations_account.registered[key].parent_id == data.aws_organizations_organizational_unit.target[account.ou_key].id
      tags_match = alltrue([
        for tag_key, tag_value in local.expected_tags[key] :
        try(data.aws_organizations_account.registered[key].tags[tag_key], null) == tag_value
      ])
    }
  }
}

data "aws_organizations_organization" "current" {}

data "aws_organizations_organizational_unit" "target" {
  for_each = var.ou_names

  name      = each.value
  parent_id = var.organization_root_id
}

data "aws_organizations_account" "registered" {
  for_each = var.account_registry

  account_id = each.value.account_id
}

check "organization_identity" {
  assert {
    condition     = data.aws_organizations_organization.current.id == var.expected_organization_id
    error_message = "The discovered Organization ID does not match expected_organization_id."
  }

  assert {
    condition     = data.aws_organizations_organization.current.master_account_id == var.expected_management_account_id
    error_message = "The discovered management account does not match expected_management_account_id."
  }

  assert {
    condition     = data.aws_organizations_organization.current.feature_set == "ALL"
    error_message = "AWS Organizations must have all features enabled for Control Tower governance."
  }

  assert {
    condition     = contains([for root in data.aws_organizations_organization.current.roots : root.id], var.organization_root_id)
    error_message = "organization_root_id is not a root of the discovered organization."
  }
}

check "canonical_ou_model" {
  assert {
    condition     = toset(keys(var.ou_names)) == local.required_ou_keys
    error_message = "ou_names must define exactly security, infrastructure, non_production, production, and sandbox."
  }
}

check "account_registry_completeness" {
  assert {
    condition     = length(setsubtract(local.required_account_keys, toset(keys(var.account_registry)))) == 0
    error_message = "account_registry must include security, log_archive, shared_services, development, staging, and production."
  }

  assert {
    condition     = length(setsubtract(toset(keys(var.account_registry)), local.allowed_account_keys)) == 0
    error_message = "account_registry contains an unsupported account key. AFT is disabled; only an optional sandbox account may be added."
  }

  assert {
    condition     = length(distinct([for account in values(var.account_registry) : account.account_id])) == length(var.account_registry)
    error_message = "Each account ID must appear exactly once in account_registry."
  }

  assert {
    condition     = alltrue([for account in values(var.account_registry) : contains(local.required_ou_keys, account.ou_key)])
    error_message = "Every member account must map to exactly one canonical ou_key."
  }
}

check "account_placement_and_metadata" {
  assert {
    condition     = alltrue([for result in values(local.placement_results) : result.name_matches])
    error_message = "At least one discovered account name differs from account_registry."
  }

  assert {
    condition     = alltrue([for result in values(local.placement_results) : result.account_state == "ACTIVE"])
    error_message = "Every registered member account must be ACTIVE."
  }

  assert {
    condition     = alltrue([for result in values(local.placement_results) : result.placement_matches])
    error_message = "At least one account is not directly attached to its declared OU."
  }

  assert {
    condition     = alltrue([for result in values(local.placement_results) : result.tags_match])
    error_message = "At least one account is missing a required ownership or classification tag."
  }
}
