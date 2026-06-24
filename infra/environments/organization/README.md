# Organization discovery and placement validation

This Terraform root is deliberately read-only. It discovers the existing AWS
Organization, five target OUs, and Control Tower-vended accounts, then evaluates
placement and tag assertions. It contains no `resource` blocks and must never be
used to create or move accounts.

`ENABLE_AFT=false` is the selected mode. Account provisioning is performed with
AWS Control Tower Account Factory as described in
[`docs/runbooks/account-vending.md`](../../../docs/runbooks/account-vending.md).

## Sensitive local inputs

Copy `account-registry.tfvars.example` to `account-registry.auto.tfvars` and
replace every typed placeholder. The resulting file is ignored by Git. An
approved secret store may instead render an ephemeral `.tfvars.json` file at
plan time. Do not commit account IDs, emails, OU IDs, backend coordinates, or
credentials.

Provider data sources can place account metadata, including account email
addresses, in Terraform state even though this root does not output them. Use
the encrypted remote backend and tightly restrict state access.

## Safe review sequence

```bash
terraform -chdir=infra/environments/organization fmt -check
terraform -chdir=infra/environments/organization init \
  -backend-config=backend.organization.hcl \
  -input=false
terraform -chdir=infra/environments/organization validate
terraform -chdir=infra/environments/organization plan \
  -input=false \
  -refresh-only \
  -var-file=account-registry.auto.tfvars
```

The plan requires read-only AWS credentials for the management account. Review
the plan summary: it must say `0 to add, 0 to change, 0 to destroy`. Failed
`check` assertions identify organization, OU, placement, naming, state, or tag
drift. Do not run `terraform apply`; a refresh-only apply would still write
state and is outside this workflow.

Use `backend.organization.hcl.example` only as a template. The real backend
file is ignored by Git.
