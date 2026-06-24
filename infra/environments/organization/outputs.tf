output "organization_summary" {
  description = "Non-sensitive organization identity used for review."
  value = {
    organization_id       = data.aws_organizations_organization.current.id
    management_account_id = data.aws_organizations_organization.current.master_account_id
    feature_set           = data.aws_organizations_organization.current.feature_set
    root_id               = var.organization_root_id
  }
}

output "organizational_units" {
  description = "Resolved canonical OU identifiers and names."
  value = {
    for key, ou in data.aws_organizations_organizational_unit.target : key => {
      id   = ou.id
      name = ou.name
      arn  = ou.arn
    }
  }
}

output "account_placement_validation" {
  description = "Placement, state, naming, and tag results. Account email addresses are intentionally excluded."
  value       = local.placement_results
}
