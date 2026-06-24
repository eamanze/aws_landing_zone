# AWS Control Tower Landing Zone Deployment Runbook

## Status and safety boundary

**Status:** operator runbook; no deployment is authorized by this document.

This runbook prepares a management account for an AWS Control Tower-first landing zone. The preferred initial path is the AWS Control Tower console. The API path is documented for controlled automation but remains a mutating operation requiring Gate C approval.

Commands explicitly labeled **read-only** may be run during readiness or validation. Commands labeled **MUTATING — APPROVAL REQUIRED** must not be run until the named approval gate is recorded.

The binding architecture decisions and unresolved values are in [decisions-and-prerequisites.md](../decisions-and-prerequisites.md). Typed placeholders such as `<ACCOUNT_ID:management>` must be resolved outside Git through the approved account registry.

## Required configuration record

Complete and approve this record before setup:

| Setting | Required value |
|---|---|
| AWS partition | `<AWS_PARTITION:commercial_or_other>` |
| Management account | `<ACCOUNT_ID:management>` |
| Organization | `<ORG_ID:organization>` or `new` |
| Control Tower home Region | `<REGION:home>`; `eu-west-1` is only a proposal |
| Additional governed Regions | `<REGION_SET:governed>`; `eu-west-2` is only a proposal |
| IAM Identity Center Region | `<REGION:identity_center>` |
| Identity source | `<IDENTITY_SOURCE:identity_center_store_active_directory_or_external_idp>` |
| Security OU | `<OU_ID:security>` and approved display name |
| Audit/Security account | `<ACCOUNT_ID:security>` or `new`; unique email stored outside Git |
| Log Archive account | `<ACCOUNT_ID:log_archive>` or `new`; unique email stored outside Git |
| Centralized logging | `enabled` unless an approved architecture decision says otherwise |
| AWS Config integration | `enabled` unless an approved architecture decision says otherwise |
| Security roles integration | `enabled` unless an approved architecture decision says otherwise |
| CloudTrail organization trail ownership | Control Tower-managed or separately approved external trail |
| Log retention | `<RETENTION_DAYS:central_logs>` and `<RETENTION_DAYS:access_logs>` |
| Setup operator | `<IDENTITY:control_tower_operator>` |
| Platform/security/billing approvers | `<APPROVERS:gate_c>` |
| AWS Support plan and escalation owner | `<SUPPORT_PLAN:organization>` / `<OWNER:aws_support>` |
| Evidence owner and retention | `<OWNER:evidence>` / `<RETENTION:evidence>` |

## Approval gates

The following gates from the decision record apply:

1. **Gate A — Architecture and prerequisites:** identity, billing, account emails, Regions, compliance, ownership, and cost are approved.
2. **Gate B — Account creation:** unique monitored emails, named owners, target OU, quotas, and account-vending mechanism are approved.
3. **Gate C — Landing-zone setup:** home/governed Regions, IAM Identity Center alignment, shared accounts, pre-launch evidence, and rollback/escalation handling are approved.

No account creation, Organizations change, trusted-access change, IAM role creation, or `CreateLandingZone` call is authorized before its gate.

## Phase 1 — Management-account readiness

### Management-account operating rules

- Use the management account only for Organizations, Control Tower, billing, account vending, and organization-level integrations.
- Do not deploy application, shared-service, security-analysis, or general CI workloads.
- Use a named federated administrator with temporary credentials for setup; do not use root for Control Tower setup.
- Confirm the legal entity, payment method, tax settings, support plan, cost owner, and AWS account quota for the required member accounts.
- Confirm service quotas allow at least the Audit/Security and Log Archive accounts, plus the planned workload accounts.
- Confirm required AWS services are available and STS endpoints are active in every proposed governed Region.
- Record the current caller, account, Organization, home Region candidate, and change ticket before setup.

### Root-user protections

- Use a unique management-account root email controlled by a monitored enterprise mailbox, not one employee.
- Register phishing-resistant/hardware MFA where supported and protect backup/recovery factors through dual custody.
- Remove root access keys; verify none exist.
- Maintain current root phone, alternate security/billing/operations contacts, and recovery procedures.
- Alert on root sign-in and root API activity through CloudTrail/EventBridge or the approved security mechanism.
- Store no root credentials, MFA recovery data, emails, or phone numbers in this repository or generated evidence.
- Test account recovery through a non-destructive tabletop exercise before landing-zone setup.
- Distinguish root recovery from `BreakGlassAdminRole`; neither is for routine administration.

## Phase 2 — Identity decision

Choose and document one IAM Identity Center model before selecting the Control Tower home Region:

| Identity source | Control Tower behavior and operator responsibility |
|---|---|
| IAM Identity Center directory | Control Tower can create groups and provision initial access; define joiner/mover/leaver and access-review ownership |
| Active Directory | Control Tower does not manage the directory or assign directory users/groups to new accounts; the identity team owns synchronization and assignments |
| External IdP | Control Tower can create Identity Center groups/assignments, while the identity team owns IdP users/groups and synchronization |

Readiness requirements:

- IAM Identity Center exists only in the Organizations management account.
- If Identity Center already exists, align the Control Tower home Region with its Region according to current AWS prerequisites; document the documented `us-east-1` exception if it applies.
- Define organization administrator, platform administrator, security audit, network administrator, read-only, incident response, and production-approval permission sets.
- Define session durations, MFA/conditional-access rules, access reviews, deprovisioning, and emergency access.
- Avoid creating IAM users for humans or long-lived CI keys.

## Phase 3 — Existing Organizations compatibility

Run the read-only organization validator before changing anything:

```bash
./scripts/validate-organization.sh \
  --profile <AWS_PROFILE:management> \
  --expected-management-account-id <ACCOUNT_ID:management> \
  --output-dir docs/evidence
```

Review:

- Whether an Organization already exists and has feature set `ALL`.
- Management account ID, root, current OUs/accounts, delegated administrators, trusted service access, and SCP inventory.
- Whether a Control Tower landing zone already exists. One landing zone is supported per Organization.
- Existing OU/account names that collide with the selected model.
- Account quotas and any pending account create/close/move operations.
- Existing AWS Config trusted access in the management account. Current Control Tower pre-launch guidance requires resolving conflicting Config trusted access/configuration before launch.
- Existing Config recorders, delivery channels, aggregators, CloudTrail trails, StackSets, service roles, and security integrations in accounts to be enrolled.
- Existing organization trails that could duplicate Control Tower logging or charges.
- Existing ALZ/custom landing-zone automation; involve the AWS account team/solutions architect before overlaying Control Tower.

Do not delete or modify compatibility conflicts merely to pass checks. Create a reviewed migration/remediation plan first.

## Phase 4 — Shared account emails and placement

Control Tower requires two unique, monitored shared-account emails when creating new accounts:

- **Audit/Security:** `<EMAIL:security>` — security operations, audit access, compliance tooling, and notification subscriptions.
- **Log Archive:** `<EMAIL:log_archive>` — central logging ownership and recovery communications.

Requirements:

- Each address is unique and not already associated with an AWS account unless intentionally enrolling that existing account.
- Use collaborative enterprise inboxes with at least two accountable custodians, monitored delivery, retention, and offboarding controls.
- Do not use plus-address aliases unless the mail platform and AWS account-recovery process have been formally approved for them.
- Record account email, root recovery, phone, owners, and alternate contacts in an access-controlled registry outside Git.
- Existing shared accounts must be free of conflicting AWS Config resources before enrollment.
- Place service integration accounts in the designated root-level Security OU. Under the API path, they must exist before `CreateLandingZone`.
- Current console terminology may vary by landing-zone version; this project retains the logical names Audit/Security and Log Archive.

Account creation and movement are **MUTATING — GATE B APPROVAL REQUIRED**.

## Phase 5 — Region decision

### Home Region

- `<REGION:home>` is the Control Tower administrative home Region.
- Treat the selection as irreversible. Changing it requires decommissioning and AWS Support assistance and is not recommended.
- Align it with existing Identity Center prerequisites, data residency, service availability, operating-team coverage, and disaster-recovery requirements.
- Landing-zone resources are created in the home Region; OUs/accounts remain global.

### Governed Regions

- Select only `<REGION_SET:governed>` where workloads or governed platform resources are expected.
- Preventive controls may have global behavior; detective/proactive coverage depends on supported/governed Regions and the selected controls.
- Adding/removing a governed Region is a landing-zone update and requires governed OUs/accounts to be updated or re-registered.
- Excluding a Region from governance does not deny resource deployment there. A separately tested Region-deny control/SCP is required for enforcement.
- Confirm STS endpoints are active in the management account for every governed Region.
- Estimate the Config, logging, KMS, security-service, and evidence cost multiplied by account and Region count.

## Phase 6 — Roles, service-linked roles, and trusted access

Do not handcraft Control Tower-managed roles when using the console setup unless AWS documentation or Support explicitly requires it. The API-only path requires pre-created service roles in the `/service-role/` path.

Expected management/control roles include:

| Role or policy | Purpose |
|---|---|
| `AWSControlTowerAdmin` with `AWSControlTowerServiceRolePolicy` | Allows Control Tower to maintain landing-zone infrastructure |
| `AWSControlTowerStackSetRole` | Allows CloudFormation to assume `AWSControlTowerExecution` in governed accounts |
| `AWSControlTowerCloudTrailRole` with `AWSControlTowerCloudTrailRolePolicy` | Publishes Control Tower CloudTrail logs to CloudWatch Logs when configured |
| `AWSServiceRoleForAWSControlTower` with `AWSControlTowerAccountServiceRolePolicy` | Service-linked account governance and drift operations |
| `AWSControlTowerExecution` | Created/used in member accounts for baselining and controls |
| `AWSControlTowerIdentityCenterManagementPolicy` | Attached when Control Tower manages Identity Center integration |

For landing zone version 4.0, do not assume older Config aggregator roles are required; validate the current manifest/integration choice and AWS documentation.

Trusted-access review:

- Record `organizations:list-aws-service-access-for-organization` before and after setup.
- Control Tower trusted access allows the service to create roles, manage resources, and read data across the Organization, including unregistered OUs/accounts; review the service permissions during setup.
- Do not manually disable trusted access, delete service-linked roles, detach managed policies, or alter Control Tower StackSets after setup.
- Register delegated administrators only through the approved security-service design.

IAM role creation, policy changes, and trusted-access changes are **MUTATING — GATE C APPROVAL REQUIRED**.

## Phase 7 — Expected landing-zone results

Depending on console/API choices and landing-zone version, expect:

- One Control Tower landing zone in `<REGION:home>`.
- AWS Organizations with the approved root-level Security OU and planned additional OUs.
- Audit/Security and Log Archive service integration accounts in the Security OU.
- Control Tower service-linked/management roles, managed policies, CloudFormation StackSets, and member-account execution/baseline roles.
- Centralized logging resources when enabled, including the selected organization CloudTrail integration and protected S3 logging.
- AWS Config integration, aggregation, and Control Tower controls when enabled.
- IAM Identity Center integration and initial groups/assignments when enabled.
- Mandatory controls plus only the optional controls explicitly selected during/after setup.
- Drift and lifecycle status visible through Control Tower.

Control Tower does not automatically implement the project's custom workload VPCs, TGW, cross-account Terraform roles, security-service organization configuration, or custom SCP gaps. Those remain later Terraform-controlled extensions.

## Phase 8 — Pre-deployment read-only commands

Set only non-secret configuration:

```bash
export AWS_PROFILE=<AWS_PROFILE:management>
export CONTROL_TOWER_HOME_REGION=<REGION:home>
export EXPECTED_MANAGEMENT_ACCOUNT_ID=<ACCOUNT_ID:management>
```

Confirm caller identity and CLI support:

```bash
aws --profile "$AWS_PROFILE" sts get-caller-identity
aws controltower list-landing-zones --generate-cli-skeleton input
aws controltower get-landing-zone --generate-cli-skeleton input
```

Run repository validators:

```bash
./scripts/validate-organization.sh \
  --profile "$AWS_PROFILE" \
  --expected-management-account-id "$EXPECTED_MANAGEMENT_ACCOUNT_ID" \
  --output-dir docs/evidence

./scripts/validate-control-tower.sh \
  --profile "$AWS_PROFILE" \
  --home-region "$CONTROL_TOWER_HOME_REGION" \
  --expect absent \
  --output-dir docs/evidence
```

Additional read-only checks:

```bash
aws --profile "$AWS_PROFILE" organizations describe-organization
aws --profile "$AWS_PROFILE" organizations list-accounts
aws --profile "$AWS_PROFILE" organizations list-aws-service-access-for-organization
aws --profile "$AWS_PROFILE" organizations list-delegated-administrators
aws --profile "$AWS_PROFILE" iam get-account-summary
aws --profile "$AWS_PROFILE" iam list-roles --path-prefix /service-role/
aws --profile "$AWS_PROFILE" controltower list-landing-zones \
  --region "$CONTROL_TOWER_HOME_REGION"
```

These commands read AWS metadata and may reveal account IDs/ARNs. Store output only under the ignored evidence directory and do not post it publicly without sanitization.

## Phase 9 — Console deployment procedure

**MUTATING — GATE C APPROVAL REQUIRED.** The console path is recommended for the initial deployment.

1. Sign in to `<ACCOUNT_ID:management>` through the approved federated Control Tower administrator identity.
2. Verify the account and switch the console to `<REGION:home>`.
3. Open the [AWS Control Tower console](https://console.aws.amazon.com/controltower) and choose **Set up your landing zone**.
4. Review pre-launch checks. Stop on any account, Organizations, Config, CloudTrail, IAM, quota, or Region failure.
5. Configure IAM Identity Center/access management according to `<IDENTITY_SOURCE:primary>` and the approved assignment model.
6. Configure the Audit/Security and Log Archive integrations using approved new or existing accounts and their unique emails.
7. Confirm the root-level Security OU and additional OU strategy. Do not create a conflicting parallel OU hierarchy accidentally.
8. Select `<REGION_SET:governed>` and verify `<REGION:home>` again before proceeding.
9. Enable centralized logging, Config, security roles, and access management according to the approved design. Record any intentionally disabled integration and compensating control.
10. Select Control Tower-managed organization CloudTrail unless the approved architecture explicitly owns an external organization trail.
11. Configure approved log retention and KMS options; do not invent values during the change window.
12. Review service permissions and Terms of Service. Export or screenshot the final configuration review without exposing emails or sensitive recovery data.
13. Choose **Set up landing zone** only after the change approver confirms the displayed account, Region, integrations, and service permissions.
14. Record the operation start time and monitor setup to terminal status.
15. Confirm required SNS subscriptions received by the Audit/Security mailbox according to current Control Tower behavior.

## Phase 10 — API deployment procedure

**MUTATING — GATE B AND GATE C APPROVAL REQUIRED. Do not execute during validation.**

For landing zone version 4.0, API setup requires:

1. An Organization with all features enabled.
2. Existing service integration accounts in the same designated root-level Security OU.
3. Required Control Tower service roles and a caller with current `CreateLandingZone` permissions.
4. A reviewed manifest with every integration `enabled` flag set explicitly.

Store the manifest in an access-controlled temporary path, not Git:

```json
{
  "accessManagement": { "enabled": true },
  "backup": { "enabled": false },
  "centralizedLogging": {
    "accountId": "<ACCOUNT_ID:log_archive>",
    "enabled": true,
    "configurations": {
      "accessLoggingBucket": { "retentionDays": "<RETENTION_DAYS:access_logs>" },
      "loggingBucket": { "retentionDays": "<RETENTION_DAYS:central_logs>" }
    }
  },
  "config": {
    "accountId": "<ACCOUNT_ID:security>",
    "enabled": true,
    "configurations": {
      "accessLoggingBucket": { "retentionDays": "<RETENTION_DAYS:access_logs>" },
      "loggingBucket": { "retentionDays": "<RETENTION_DAYS:config_logs>" }
    }
  },
  "governedRegions": ["<REGION:home>", "<REGION:additional>"],
  "securityRoles": {
    "enabled": true,
    "accountId": "<ACCOUNT_ID:security>"
  }
}
```

Validate the manifest against the current AWS schema and approved choices. JSON numbers must replace retention placeholders; do not submit placeholder text.

Approved launch command:

```bash
aws --profile <AWS_PROFILE:management> controltower create-landing-zone \
  --region <REGION:home> \
  --landing-zone-version 4.0 \
  --manifest file://<SECURE_PATH:landing-zone-manifest.json>
```

Record the returned operation identifier and monitor it read-only:

```bash
aws --profile <AWS_PROFILE:management> controltower get-landing-zone-operation \
  --region <REGION:home> \
  --operation-identifier <OPERATION_ID:create_landing_zone>
```

Do not assume `4.0` remains current indefinitely; verify the supported/latest landing-zone version immediately before an approved future deployment.

## Phase 11 — Post-deployment validation

After setup reaches `SUCCEEDED`, run:

```bash
./scripts/validate-organization.sh \
  --profile <AWS_PROFILE:management> \
  --expected-management-account-id <ACCOUNT_ID:management> \
  --expected-ou Security \
  --expected-account <ACCOUNT_NAME:security> \
  --expected-account <ACCOUNT_NAME:log_archive> \
  --output-dir docs/evidence

./scripts/validate-control-tower.sh \
  --profile <AWS_PROFILE:management> \
  --home-region <REGION:home> \
  --expect present \
  --target-ou-arn <OU_ARN:security> \
  --output-dir docs/evidence
```

Then verify:

- Landing-zone status, version, manifest, governed Regions, and drift status.
- Audit/Security and Log Archive accounts are in the Security OU.
- Expected service roles, trusted service access, StackSets/baselines, and mandatory controls exist.
- IAM Identity Center assignments work with temporary sessions.
- Organization CloudTrail/Config integrations are healthy and logs arrive centrally.
- Control Tower reports OUs/accounts healthy and in sync.
- No duplicate trails/Config resources or unexpected public/default resources were created.
- Billing/cost monitoring and support contacts are active.

Do not enable custom SCPs or Terraform extensions until the landing-zone baseline is healthy and evidence is reviewed.

## Phase 12 — Failure, rollback, and escalation

Control Tower setup is not a simple transactional Terraform deployment. Do not improvise manual rollback.

On failure:

1. Stop new account, OU, policy, Config, CloudTrail, Identity Center, and StackSet changes.
2. Capture the landing-zone operation ID/status, UTC timestamps, management account, home Region, manifest/configuration selections, and exact error.
3. Capture relevant read-only Control Tower status, CloudFormation stack/StackSet events, Organizations inventory, and CloudTrail events.
4. Check quotas, STS Region activation, IAM role/trust policies, shared-account placement, emails, existing Config/CloudTrail conflicts, and Organizations trusted access.
5. Do not delete Control Tower roles, StackSets, buckets, trails, OUs, accounts, or service-linked roles to force a retry.
6. Follow the AWS-documented remediation/retry path. A reset is mutating and is not a generic first response; it requires the supported/latest landing-zone version and approval.
7. Open an AWS Support case when the operation remains failed, partial resources cannot be reconciled safely, home Region/decommissioning is involved, or AWS-managed resources are drifted.

AWS Support evidence should include sanitized operation IDs, Region, landing-zone version, failed resource/stack identifiers, timestamps, request IDs, and completed diagnostics. Never include passwords, access keys, session tokens, MFA data, or root recovery information.

Decommission/delete/reset operations can remove governance while leaving accounts/resources behind. Treat them as separate production changes with impact analysis, log preservation, identity recovery, billing ownership, and AWS Support guidance.

## Phase 13 — Evidence package

Store raw generated output under ignored `docs/evidence/`; sanitize before any commit.

Recommended evidence set:

| File | Evidence |
|---|---|
| `control-tower-preflight-<UTC>/caller-identity.json` | Management caller/account confirmation |
| `organization-validation-<UTC>/organization.json` | Organization ID, feature set, management account |
| `organization-validation-<UTC>/accounts.json` | Sanitized account inventory |
| `organization-validation-<UTC>/organizational-units.json` | OU hierarchy |
| `organization-validation-<UTC>/trusted-service-access.json` | Trusted service integrations |
| `organization-validation-<UTC>/delegated-administrators.json` | Delegated admin inventory |
| `control-tower-validation-<UTC>/landing-zones.json` | Landing-zone discovery |
| `control-tower-validation-<UTC>/landing-zone-*.json` | Version, manifest, drift/status |
| `control-tower-validation-<UTC>/enabled-controls-*.json` | Controls per supplied OU ARN |
| `control-tower-validation-<UTC>/management-service-roles.json` | Control Tower-related management roles |
| `control-tower-operation.md` | Approved configuration, operation ID, start/end, result |
| `central-log-delivery.md` | Events from each governed account in central logging |
| `identity-center-access.md` | Sanitized permission-set/session validation |
| `exceptions.md` | Known failures, owners, SLAs, and remediation |

## Terraform ownership warning

**Do not import Control Tower-owned resources into Terraform.**

This includes the landing zone, mandatory controls, Control Tower service-linked/management roles, managed StackSets/stack instances, Control Tower-owned CloudTrail/Config resources, Account Factory products, governed-account baselines, and shared-account baseline resources. Terraform may consume identifiers and manage separately documented extensions only after ownership review.

Control Tower drift is remediated through supported Control Tower lifecycle operations. Terraform drift is remediated only for Terraform-owned extensions.

## Official references

- [Getting started with AWS Control Tower](https://docs.aws.amazon.com/controltower/latest/userguide/getting-started-with-control-tower.html)
- [Control Tower pre-launch checks](https://docs.aws.amazon.com/controltower/latest/userguide/getting-started-prereqs.html)
- [Console setup](https://docs.aws.amazon.com/controltower/latest/userguide/getting-started-from-console.html)
- [API setup](https://docs.aws.amazon.com/controltower/latest/userguide/getting-started-apis.html)
- [Landing zone API launch and version 4.0 manifest](https://docs.aws.amazon.com/controltower/latest/userguide/lz-api-launch.html)
- [Control Tower roles and policies](https://docs.aws.amazon.com/controltower/latest/userguide/access-control-managing-permissions.html)
- [Control Tower account roles and trusted access](https://docs.aws.amazon.com/controltower/latest/userguide/roles-how.html)
- [Regions and home Region behavior](https://docs.aws.amazon.com/controltower/latest/userguide/region-how.html)
- [Reset landing zone guidance](https://docs.aws.amazon.com/controltower/latest/userguide/lz-api-reset.html)
