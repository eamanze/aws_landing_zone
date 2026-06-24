# Account baseline module

Composes the reusable IAM cross-account role module for a Control Tower-enrolled
account and adds immediate EventBridge monitoring when break-glass access is
enabled. It does not create accounts, OUs, Identity Center resources, Control
Tower baselines, access keys, OIDC providers, alert destinations, or permission
boundaries.

## Ownership

- **Owner:** the target account's Terraform baseline state.
- **Deployment:** after Account Factory provisioning/enrollment and separate
  account-baseline approval.
- **Provider:** passed by the account environment root after assuming that
  account's Terraform execution role.
- **Control Tower boundary:** custom IAM roles and monitoring only. Never import
  or modify Control Tower execution roles, service-linked roles, managed
  StackSets, Config, or CloudTrail resources.

Role selection is explicit per account. `OrganizationAdminRole` is restricted to
the management baseline. `AFTExecutionRole` exists only when `enable_aft=true`
and the account type is `aft`. The repository currently selects
`ENABLE_AFT=false`, so no AFT role should appear in plans.

## Human access

Use IAM Identity Center permission sets directly for routine admin, audit,
network, read-only, and incident-response access. Enable the corresponding
custom IAM role only when a separately justified cross-account path is required.
Every enabled human role must trust one or more exact IAM role ARNs and requires
MFA at STS role assumption. Wildcard principals and account-root trust are
rejected.

## Automation access

`TerraformExecutionRole` requires exact OIDC conditions. For GitHub Actions,
configure the existing GitHub OIDC provider ARN, issuer
`token.actions.githubusercontent.com`, audience `sts.amazonaws.com`, and exact
subjects for approved repositories and protected branches/environments. Do not
use wildcard subjects or static AWS keys.

The module intentionally provides no default Terraform or AFT permission policy.
Pass a customer-managed least-privilege policy ARN scoped to the resources that
the environment state owns. A permission boundary should cap all roles.

## Broad-permission review

- `BreakGlassAdminRole` attaches AWS `AdministratorAccess`. This is deliberately
  broad because it is the emergency recovery path. Creation requires the exact
  acknowledgement string, an MFA-protected exact trusted role, and an alert
  target. Its one-hour session is not configurable here.
- The AWS-managed Network Administrator policy can be broader than an individual
  workload needs. Replace or cap it with a boundary when resource scoping is
  known.
- AWS-managed `SecurityAudit` and `ReadOnlyAccess` evolve as AWS adds services.
  Review managed-policy changes and use customer-managed policies where a stable
  permission contract is required.
- Organization actions commonly require `Resource = "*"`. The included policy
  restricts actions to discovery, policy lifecycle/attachment, service access,
  delegated administrators, and Organizations tagging. It deliberately excludes
  account creation, account movement, organization deletion, and leaving the
  organization.

## Break-glass operations

The EventBridge rule relies on CloudTrail management events and matches every
`sts:AssumeRole` request for the generated break-glass role ARN. The supplied
target must already exist and permit EventBridge delivery. Before apply, verify:

1. organization/account CloudTrail management events are active in every
   governed Region;
2. the event target is owned by security operations and tested;
3. alerts page a monitored channel and create an incident/ticket;
4. access requires two named custodians or another approved dual-control process;
5. every use records reason, approver, session identity, actions, and closure;
6. CloudTrail and central-log evidence is reviewed immediately after use;
7. access is tested periodically without weakening normal controls.

EventBridge delivery failure monitoring and destination policies remain the
environment owner's responsibility. Root credentials are a separate recovery
mechanism and must not be treated as this role.

## Example shape

```hcl
module "account_baseline" {
  source = "../../modules/account-baseline"

  account_type = "production"
  enabled_roles = [
    "SecurityAuditRole",
    "NetworkAdminRole",
    "TerraformExecutionRole",
    "ReadOnlyRole",
    "IncidentResponseRole",
    "BreakGlassAdminRole",
  ]

  human_trusted_principal_arns = {
    SecurityAuditRole     = [var.security_audit_source_role_arn]
    NetworkAdminRole      = [var.network_admin_source_role_arn]
    ReadOnlyRole          = [var.read_only_source_role_arn]
    IncidentResponseRole  = [var.incident_response_source_role_arn]
    BreakGlassAdminRole   = [var.break_glass_source_role_arn]
  }

  terraform_oidc = {
    provider_arn = var.ci_oidc_provider_arn
    issuer       = "token.actions.githubusercontent.com"
    audiences    = ["sts.amazonaws.com"]
    subjects     = ["repo:<GITHUB_ORG:platform>/<GITHUB_REPOSITORY:landing-zone>:environment:production"]
  }

  additional_managed_policy_arns = {
    TerraformExecutionRole = [var.production_terraform_policy_arn]
  }

  permissions_boundary_arn       = var.permissions_boundary_arn
  break_glass_acknowledgement     = "I acknowledge monitored emergency administrator access"
  break_glass_alert_target_arn    = var.security_alert_topic_arn
  enable_aft                      = false
  tags                            = var.tags
}
```

Account IDs, principal ARNs, policy ARNs, OIDC subjects, and alert targets belong
in ignored environment configuration or an approved secret/configuration store.
Run `terraform test` for mocked plan tests. Review an environment-specific plan
and stop before apply.

For an approved interactive cross-account test, use
`scripts/assume-role.sh --role-arn <ROLE_ARN> --mfa-serial <MFA_ARN>`. The script
holds returned credentials in process memory and executes the requested command;
it never prints or writes credentials. CI should use its OIDC exchange directly,
not this interactive helper and not stored access keys.
