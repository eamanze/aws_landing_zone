# Account Vending and Placement Runbook

## Status and safety boundary

| Setting | Decision |
|---|---|
| Landing-zone mode | Control Tower first |
| `ENABLE_AFT` | `false` |
| Account-vending mechanism | AWS Control Tower Account Factory |
| Terraform role | Read-only discovery, placement validation, and post-vending extensions only |
| Current authorization | Documentation, local validation, and plan/dry-run only |

This runbook does **not** authorize creating an account, moving an account,
registering an OU, enrolling an account, updating a managed account, or running
Terraform apply. Stop at the approval gate in each operational section.

The selected mode follows the project decision in
[`decisions-and-prerequisites.md`](../decisions-and-prerequisites.md): the initial
fixed account set does not justify AFT's dedicated management account and
pipelines. AWS describes Account Factory as the Control Tower mechanism for
provisioning and updating enrolled accounts; see [Provision and manage accounts
with Account Factory](https://docs.aws.amazon.com/controltower/latest/userguide/account-factory.html).

## Canonical OU and account model

```text
Organizations Root
├── Management account (must remain at Root; no workloads)
├── Security OU
│   ├── Security / Audit account
│   └── Log Archive account
├── Infrastructure OU
│   └── Shared Services account
├── Non-Production OU
│   ├── Development account
│   └── Staging account
├── Production OU
│   └── Production account
└── Sandbox OU
    └── Optional Sandbox account
```

The management account is the required root-level exception: it is not a member
account and cannot be placed in a child OU. Every member account in the registry
must declare exactly one `ou_key`; the validation configuration rejects duplicate
account IDs, missing required accounts, unknown account keys, unknown OU keys,
and placement that does not match the declared direct parent.

| Registry key | Account | Exactly one target OU | Account owner | Required environment tag |
|---|---|---|---|---|
| `security` | Security / Audit | Security | `<OWNER:security_team>` | `security` |
| `log_archive` | Log Archive | Security | `<OWNER:security_team>` | `logging` |
| `shared_services` | Shared Services | Infrastructure | `<OWNER:platform_team>` | `shared-services` |
| `development` | Development | Non-Production | `<OWNER:development>` | `development` |
| `staging` | Staging | Non-Production | `<OWNER:staging>` | `staging` |
| `production` | Production | Production | `<OWNER:production>` | `production` |
| `sandbox` | Optional Sandbox | Sandbox | `<OWNER:sandbox>` | `sandbox` |

The AFT management account is intentionally absent while `ENABLE_AFT=false`.
If AFT is approved later, it belongs in Infrastructure and must be added only
after the AFT prerequisite decision is revisited.

## Registry, ownership, and tags

The controlled account-request record must contain:

- unique monitored root email and recovery contacts (never place these in Git);
- account display name and intended workload/data classification;
- one canonical target OU;
- named business owner and technical owner;
- `Project`, `Environment`, `Owner`, `CostCenter`, and `ManagedBy` tags;
- budget, support-plan, identity assignment, and break-glass ownership;
- approved Regions, network allocation, and baseline profile;
- request, security, billing, and production approver references.

The committed files contain typed placeholders only. After vending, store account
and OU IDs in either:

1. an approved secret/configuration store rendered into ephemeral plan inputs; or
2. local `account-registry.auto.tfvars` and `account-registry.json` files.

Both local filenames are ignored by `.gitignore`. Apply filesystem permissions
of `0600`, do not place account emails in Terraform variables, and do not commit
generated evidence. The AWS provider's Organizations account data source can
write returned metadata to state, so remote state must be encrypted and
least-privilege. HashiCorp documents data-source behavior in the [AWS provider
Organizations account data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/organizations_account).

For these Control Tower-vended account records, `Project` is
`multi-account-landing-zone` and `ManagedBy` is `control-tower`. Terraform-owned
resources inside those accounts retain the repository standard
`ManagedBy=terraform`; this distinction prevents account lifecycle ownership
from being confused with resource lifecycle ownership.

## Account Factory provisioning workflow

### Phase 1 — request and approval (no AWS mutation)

1. Create a request record with every registry, ownership, identity, budget,
   Region, logging, network, and tag field above.
2. Confirm the root email is unique, monitored, and not already associated with
   another AWS account. Do not store the address in this repository.
3. Confirm the target OU exists, is registered/governed by Control Tower, and
   has the intended controls. Never use an ungoverned OU merely to bypass a
   control.
4. Confirm the account name and email satisfy current Account Factory
   constraints and the organization has account capacity.
5. Review IAM Identity Center access assignments and the initial account user or
   federated access model. Avoid creating routine IAM users.
6. Review default VPC handling, governed Regions, data residency, CIDR request,
   budgets, support, and expected recurring security/logging costs.
7. Record security, billing, organization-administrator, and workload-owner
   approvals. Production requires its change record and production approver.
8. Stop. The approved request is necessary but is not permission for this
   repository or Terraform to create the account.

### Phase 2 — Account Factory operator action (explicit mutation gate)

Only after separate, explicit account-creation approval, an authorized Control
Tower operator may open Account Factory in the Control Tower home Region, select
the approved governed OU, enter the approved account identity fields, and submit
the product/request. Follow the current AWS console workflow rather than copying
screens from this runbook because Control Tower changes its console over time.

Track the request until Control Tower reports completion. Do not simultaneously
create the account with AWS Organizations or Terraform. In particular, this
repository must never use `aws_organizations_account` for a Control Tower-vended
account. AWS documents the Account Factory workflow and constraints in
[Account Factory considerations](https://docs.aws.amazon.com/controltower/latest/userguide/account-factory-considerations.html).

### Phase 3 — capture and verify (read-only)

1. Obtain the new account ID and OU ID from the approved inventory/secret-store
   process; do not copy the root email into Terraform.
2. Update the ignored local Terraform and JSON registries.
3. Run the placement validator in live read-only mode from the management
   account. It verifies the organization, root, all five OUs, account state,
   direct parent, display name, and required ownership tags.
4. Run a Terraform refresh-only plan. It must report zero managed-resource
   changes; `check` failures are drift signals, not permission to remediate.
5. Verify Control Tower enrollment and control status separately using the
   existing read-only Control Tower validator.
6. Store sanitized outputs under `docs/evidence/` only in the controlled evidence
   workflow. That directory is ignored because identifiers and findings may be
   sensitive.
7. Obtain a new approval before applying any Terraform-owned account baseline.

## Existing account enrollment

Enrollment is a Control Tower lifecycle operation, not a Terraform operation.
Before asking an operator to enroll an existing account:

1. Confirm it belongs to the same organization and is in an eligible OU.
2. Assess existing AWS Config recorders/delivery channels, CloudTrail, IAM roles,
   SCPs, Config aggregators, and resources that can conflict with the Control
   Tower baseline.
3. Confirm required execution-role trust and permissions using the current AWS
   enrollment prerequisites; do not invent or modify the role from this runbook.
4. Confirm account access, root email ownership, Regions, identity assignments,
   and the target governed OU.
5. Take a read-only inventory and recovery snapshot of relevant configuration.
6. Obtain explicit enrollment approval, then stop. An authorized Control Tower
   operator performs enrollment or OU registration using the supported Control
   Tower workflow.
7. After completion, run the same read-only placement, Control Tower status,
   logging, and controls validation used for a newly vended account.

See AWS's current [Enroll an existing AWS account](https://docs.aws.amazon.com/controltower/latest/userguide/enroll-account.html)
and [Considerations for enrolling existing accounts](https://docs.aws.amazon.com/controltower/latest/userguide/enroll-existing-account.html)
before each enrollment. Existing configurations and SCPs can prevent successful
enrollment, so treat the procedure as a reviewed change.

## Drift and remediation

Classify drift before acting:

| Drift class | Detection | Owner | Approved remediation path |
|---|---|---|---|
| Account is in the wrong OU | Placement script/Terraform check | Organizations + Control Tower operator | Approve the intended placement, assess controls, then use the supported Control Tower/Organizations process; never auto-move |
| Governed OU or account baseline drift | Control Tower status | Control Tower operator | Use the Control Tower repair, update, reset, or re-register workflow appropriate to the reported drift |
| Landing-zone version drift | Control Tower status | Landing-zone owner | Plan and approve a landing-zone update before governed OU/account updates |
| Terraform extension drift | Terraform plan | Platform owner | Review plan and ownership boundary; apply only through the environment approval gate |
| Tag/ownership metadata drift | Placement script/Terraform check | Account owner + Organizations admin | Correct through the approved tagging/inventory workflow after review |

Never import Control Tower-owned baselines, StackSets, roles, trails, Config
resources, mandatory controls, or Account Factory products into Terraform.
AWS documents drift categories and repair options in [Detect and resolve drift
in AWS Control Tower](https://docs.aws.amazon.com/controltower/latest/userguide/drift.html)
and managed-account update behavior in [Update a member account](https://docs.aws.amazon.com/controltower/latest/userguide/update-account.html).

## Read-only validation and dry run

Offline dry run, using only placeholder data and making no AWS calls:

```bash
./scripts/validate-account-placement.sh \
  --registry-file infra/environments/organization/account-registry.json.example \
  --dry-run
```

Live read-only validation after real identifiers are stored locally:

```bash
chmod 600 infra/environments/organization/account-registry.json
AWS_PROFILE=<PROFILE:management_read_only> \
AWS_REGION=<AWS_REGION:control_tower_home> \
./scripts/validate-account-placement.sh \
  --registry-file infra/environments/organization/account-registry.json \
  --output-dir docs/evidence/account-vending
```

Terraform read-only discovery plan:

```bash
cp infra/environments/organization/backend.organization.hcl.example \
  infra/environments/organization/backend.organization.hcl
cp infra/environments/organization/account-registry.tfvars.example \
  infra/environments/organization/account-registry.auto.tfvars
# Replace typed placeholders locally, then:
terraform -chdir=infra/environments/organization init \
  -backend-config=backend.organization.hcl \
  -input=false
terraform -chdir=infra/environments/organization validate
terraform -chdir=infra/environments/organization plan \
  -refresh-only \
  -input=false \
  -var-file=account-registry.auto.tfvars
```

The live commands require read-only access to Organizations plus
`sts:GetCallerIdentity`. The Terraform provider is pinned to the expected
management account so credentials from another account fail closed. Review the
plan for `0 to add, 0 to change, 0 to destroy`. Do not apply it.

The script issues only the documented read APIs: [DescribeOrganization](https://docs.aws.amazon.com/organizations/latest/APIReference/API_DescribeOrganization.html),
[ListRoots](https://docs.aws.amazon.com/organizations/latest/APIReference/API_ListRoots.html),
[DescribeOrganizationalUnit](https://docs.aws.amazon.com/organizations/latest/APIReference/API_DescribeOrganizationalUnit.html),
[DescribeAccount](https://docs.aws.amazon.com/organizations/latest/APIReference/API_DescribeAccount.html),
[ListParents](https://docs.aws.amazon.com/organizations/latest/APIReference/API_ListParents.html),
and [ListTagsForResource](https://docs.aws.amazon.com/organizations/latest/APIReference/API_ListTagsForResource.html).

## AFT reassessment gate

Do not implement `infra/modules/aft-account-request` or an AFT repository layout
while `ENABLE_AFT=false`. Set it to `true` only through an approved decision that
demonstrates repeatable GitOps account vending is required and validates, at a
minimum:

- a healthy, current Control Tower landing zone and governed target OUs;
- a dedicated AFT management account in Infrastructure;
- supported Terraform/AFT versions and Control Tower home Region;
- approved source-control provider, repositories, branches, encryption keys,
  pipeline access, execution roles, and state backends;
- account-request schema, global/OU/account customization ownership, and tests;
- quotas, networking/egress, support, logging, alerting, cost, backup, and on-call
  ownership;
- separation between AFT account provisioning/customization and application
  workload deployment.

Only after those checks pass may a separate change implement AFT. See the
official [AFT prerequisites](https://docs.aws.amazon.com/controltower/latest/userguide/aft-getting-started.html)
and [AFT overview](https://docs.aws.amazon.com/controltower/latest/userguide/aft-overview.html).

## Stop point and unresolved approvals

No account has been created, moved, registered, enrolled, updated, or tagged by
this implementation. Before any such action, resolve and approve:

- [ ] Management, organization root, OU, and existing account identifiers.
- [ ] Unique account root emails and recovery contacts outside Git.
- [ ] Named owners, cost centers, budgets, support, and required tags.
- [ ] Final account names and whether a Sandbox account is required.
- [ ] Identity Center assignments and break-glass custodians.
- [ ] Governed Regions, data residency, networking, and CIDR allocations.
- [ ] Target OU controls and any enrollment conflicts.
- [ ] Account-creation or enrollment change record and named approvers.
- [ ] Approved encrypted state backend and read-only execution role.
- [ ] Separate approval for each Terraform-owned baseline apply.
