# Control Tower Landing Zone Decisions and Prerequisites

## Document status

| Field | Value |
|---|---|
| Project | Production-Grade Multi-Account AWS Landing Zone using AWS Control Tower and Terraform |
| Decision status | Proposed; blocked on the REQUIRED inputs and approval gates below |
| Recommended implementation | AWS Control Tower first, extended by Terraform |
| AFT decision | Defer for the initial implementation |
| Last reviewed | 2026-06-23 |
| Source of project requirements | `AGENTS.md`, `README.md`, and all files under `skills/` |

This document records architecture decisions only. It does not authorize AWS account creation, AWS Control Tower setup, policy attachment, or Terraform apply.

## 1. Supplied values and required inputs

`REQUIRED` means the value is not supplied by the repository and must be approved before the associated action. Example values in `AGENTS.md` are not treated as approved deployment values.

| Value | Current value | Status and consequence |
|---|---|---|
| Project name | Multi-Account AWS Landing Zone | Supplied |
| Implementation objective | Production-grade, governed, repeatable multi-account AWS foundation | Supplied |
| Preferred implementation mode | Control Tower first, extended with Terraform | Supplied |
| Alternative implementation mode | Manual AWS Organizations for a lab or portfolio environment | Supplied, not selected |
| AWS partition | `aws` | REQUIRED: confirm commercial AWS rather than GovCloud or China |
| Management account ID | Not supplied | REQUIRED before validation or deployment |
| Management account email and owner | Not supplied | REQUIRED before Control Tower setup |
| Existing AWS Organizations status | Not supplied | REQUIRED: new organization or existing organization |
| Existing Control Tower status | Not supplied | REQUIRED: confirm no landing zone already exists |
| Existing IAM Identity Center Region and identity source | Not supplied | REQUIRED before selecting the home Region |
| Control Tower home Region | Proposed `eu-west-1` (Europe/Ireland) | REQUIRED approval; cannot be changed after landing-zone creation |
| Additional governed Regions | Proposed `eu-west-2` (Europe/London) | REQUIRED approval; `eu-west-1` and `eu-west-2` occur only in an example Region SCP |
| Region-deny policy | Not approved | REQUIRED before any Region restriction is attached |
| Security/Audit account email, ID, and owner | Not supplied | REQUIRED before account creation or enrollment |
| Log Archive account email, ID, and owner | Not supplied | REQUIRED before account creation or enrollment |
| Shared Services account email, ID, and owner | Not supplied | REQUIRED before account vending |
| Development account email, ID, and owner | Not supplied | REQUIRED before account vending |
| Staging account email, ID, and owner | Not supplied | REQUIRED before account vending |
| Production account email, ID, and owner | Not supplied | REQUIRED before account vending |
| AFT management account email, ID, and owner | Not supplied | Optional; REQUIRED only if AFT is approved later |
| Account email strategy | Not supplied | REQUIRED: every AWS account needs a unique, monitored email address |
| Organization legal/billing owner | Not supplied | REQUIRED before adding billable accounts and services |
| AWS Support plan | Not supplied | REQUIRED cost and operating-model decision |
| Cost center | Not supplied | REQUIRED before implementing mandatory tags |
| Platform owner | `platform-team` | Supplied as the Terraform tag default; named owner REQUIRED |
| Approved administrators and security approvers | Not supplied | REQUIRED before privileged access is configured |
| External identity provider | Not supplied | REQUIRED: IAM Identity Center user store or named external IdP |
| Terraform version | Not supplied and Terraform is not currently on `PATH` | REQUIRED before backend/module implementation |
| AWS provider version | Not supplied | REQUIRED before Terraform implementation |
| Terraform state account, bucket name, Region, and recovery owners | Not supplied | REQUIRED before remote-state bootstrap |
| Terraform state locking | S3 lockfile proposed | REQUIRED approval; repository guidance specifying DynamoDB is obsolete for new builds |
| CI/CD platform and repository identity | GitHub Actions implied by repository structure | REQUIRED confirmation before OIDC trust is created |
| Log retention | Not supplied | REQUIRED before S3 lifecycle or Object Lock decisions |
| Evidence retention and sensitivity classification | Not supplied | REQUIRED before evidence automation |
| CIDR allocations | Dev `10.10.0.0/16`, staging `10.20.0.0/16`, production `10.30.0.0/16`, shared services `10.40.0.0/16`, security `10.50.0.0/16`, logging `10.60.0.0/16` | Supplied as examples only; REQUIRED validation against enterprise IPAM and connected networks |
| NAT Gateway strategy | Not supplied | REQUIRED cost/resilience decision |
| Transit Gateway/shared network hub | Proposed by project, not approved | REQUIRED architecture and cost decision |
| Data residency and compliance requirements | Not supplied | REQUIRED before Regions, controls, encryption, and retention are finalized |

AWS Control Tower performs management-account pre-launch checks. If IAM Identity Center already exists, its Region constrains the Control Tower home Region, with a documented exception for an instance in `us-east-1`. STS endpoints must be active in every governed Region. Existing AWS Config and CloudTrail arrangements also require review before account enrollment. See [AWS Control Tower pre-launch checks](https://docs.aws.amazon.com/controltower/latest/userguide/getting-started-prereqs.html).

## 2. Implementation-mode comparison

| Criterion | Control Tower first | Manual AWS Organizations | Control Tower with AFT |
|---|---|---|---|
| Landing-zone baseline | AWS-managed, prescriptive landing zone | Team designs and operates every baseline component | Control Tower baseline |
| Organization and OUs | AWS Organizations under Control Tower governance | Directly managed through Organizations/Terraform | AWS Organizations under Control Tower governance |
| Audit and log accounts | Control Tower creates or incorporates the Audit and Log Archive pattern | Team creates and secures them | Control Tower pattern |
| Account vending | Account Factory and enrollment workflow | Terraform `aws_organizations_account` or manual process | Git-driven Terraform account requests through AFT |
| Controls | Native preventive, detective, and proactive controls first | Custom SCPs, Config rules, and automation | Native controls plus Terraform customizations |
| Drift/lifecycle | Control Tower landing-zone and governed-OU lifecycle | Entirely team-owned | Control Tower plus AFT pipeline lifecycle |
| Terraform scope | Custom extensions; avoid Control Tower-owned resources | Broad ownership of organization and baseline resources | Account requests/customizations plus custom extensions |
| Operational effort | Moderate | Highest | Highest initial complexity, but useful at account-vending scale |
| Best fit | Production-style environment and this repository's objective | Cost-constrained lab or deliberate learning exercise | Mature platform needing repeatable GitOps account vending |
| Main risk | Terraform/Control Tower ownership conflict | Missing controls, higher maintenance, and custom drift handling | Extra account, pipelines, component services, cost, and troubleshooting surface |

AWS documents that Control Tower can establish a landing zone in a new or existing organization, creates Audit and Log Archive accounts when added to an existing organization, and supports one landing zone per organization. See [Plan your AWS Control Tower landing zone](https://docs.aws.amazon.com/controltower/latest/userguide/planning-your-deployment.html).

### Decision

Select **Control Tower first, extended by Terraform**.

Rationale:

- It is the explicit production preference in `AGENTS.md` and every relevant skill guide.
- It provides the governed account, logging, audit, control, and enrollment baseline that the project is intended to demonstrate.
- It reduces custom implementation of foundational governance while retaining Terraform for organization-specific platform engineering.
- It makes the ownership boundary explicit: Control Tower operates its baseline; Terraform extends it.
- Manual Organizations remains a valid fallback only if the user explicitly reclassifies this as a lab and documents why Control Tower is unavailable.

## 3. Account model

| Account | OU | Purpose | Prohibited or constrained use |
|---|---|---|---|
| Management | Organization root/management account | Control Tower, Organizations, billing, account vending, organization integrations, and a minimal state-bootstrap/control-plane footprint if approved | No application workloads; very limited administrators; no routine human changes |
| Security/Audit | Security | Delegated administration for GuardDuty, Security Hub, Access Analyzer, Config aggregation where appropriate, incident response, audit access, and security automation | No general workloads; separation of security operations from platform/workload administration |
| Log Archive | Security | Protected organization CloudTrail, Config, VPC Flow Log, and other approved audit-log storage | No workloads; tightly restricted read/delete access; workload administrators must not control evidence |
| Shared Services | Infrastructure | Network hub, shared DNS, approved CI/CD services, artifacts, observability, and shared operational tooling | Must not become a general workload account or a substitute for environment isolation |
| Development | Non-Production | Development workloads, experimentation within guardrails, and Terraform module testing | No production data or ungoverned experimentation |
| Staging | Non-Production | Production-like integration, performance, release, and security validation | No live production traffic unless explicitly designed and approved |
| Production | Production | Live workloads with strict access, logging, encryption, backup, monitoring, and change controls | No unmanaged direct changes except a documented break-glass procedure |
| AFT Management (optional) | Infrastructure | AFT pipelines, account request metadata, global/account customizations, and account-vending automation | Not approved for the initial build; no application workloads |

Account identifiers, emails, owners, budget contacts, and alternate contacts must be recorded in an access-controlled account registry before vending.

## 4. OU decision

Select the stricter OU model:

```text
Root
├── Security
│   ├── Security / Audit
│   └── Log Archive
├── Infrastructure
│   ├── Shared Services
│   └── AFT Management (optional, deferred)
├── Non-Production
│   ├── Development
│   └── Staging
├── Production
│   └── Production
└── Sandbox
    └── Future experimental accounts
```

Justification:

- Production needs stricter controls and approval paths than non-production.
- Security evidence and delegated administration require an independent boundary.
- Infrastructure accounts have different network and platform permissions from workloads.
- Sandbox provides a safe target for testing controls before development, staging, and production.
- The model remains small enough to operate without creating an OU for every account.

Control attachments must target the narrowest appropriate OU. No new custom SCP is attached to Root during initial rollout.

## 5. Region decision

| Setting | Decision |
|---|---|
| Home Region | **REQUIRED approval**; propose `eu-west-1` |
| Additional governed Region | **REQUIRED approval**; propose `eu-west-2` |
| Workload deployment outside governed Regions | Denied only after a tested Region-deny control and exception model are approved |
| Opt-in Regions | Disabled unless explicitly required and governed |

`eu-west-1` is proposed because it is a supported Control Tower Region and appears in the repository's examples. `eu-west-2` is proposed as the secondary governed Region for the same reason. Neither example constitutes business approval or a data-residency decision.

The home Region is difficult to reverse: AWS states it cannot be changed after selection. Adding or removing governed Regions updates/baselines the landing zone, and existing governed OUs/accounts must be updated or re-registered. Opting out of governance does not itself prevent resource deployment in a Region. See [How AWS Regions work with AWS Control Tower](https://docs.aws.amazon.com/controltower/latest/userguide/region-how.html).

## 6. Resource ownership boundary

### Control Tower-owned or Control Tower-lifecycle resources

| Area | Ownership rule |
|---|---|
| Landing zone and its manifest | Control Tower |
| Mandatory controls and Control Tower-enabled controls | Control Tower; enable through supported Control Tower workflows |
| Governed OU/account baselines | Control Tower and its managed StackSets/baselines |
| Control Tower service-linked and execution roles | Control Tower |
| Audit and Log Archive account baseline | Control Tower |
| Control Tower-managed organization CloudTrail and AWS Config resources | Control Tower when enabled/configured by the landing zone |
| Account Factory products and enrollment lifecycle | Control Tower |
| IAM Identity Center groups/assignments created by Control Tower | Control Tower lifecycle unless explicitly documented otherwise |

Terraform must not import, replace, modify, or delete these resources unless an architecture decision explicitly transfers ownership and documents the lifecycle consequence.

### Terraform-owned extensions

| Area | Ownership rule |
|---|---|
| Remote state backend | Terraform bootstrap, outside a backend dependency cycle |
| Custom cross-account IAM roles and permission boundaries | Terraform, with explicit trust policies |
| Custom SCPs not satisfied by Control Tower controls | Terraform after control mapping, sandbox testing, and approval |
| Workload VPCs, subnets, endpoints, routing, and Flow Logs | Terraform |
| Transit Gateway, shared network services, and private DNS | Terraform if approved |
| Security delegated-admin configuration and organization extensions | Terraform where Control Tower does not own the resource |
| Account public-access blocks, encryption defaults, alert routing, and workload baselines | Terraform where compatible with Control Tower |
| CI/CD OIDC roles and deployment automation | Terraform after trust boundaries are approved |
| Validation scripts and evidence templates | Repository code/CI |

Before every module is implemented, its README must state the resource owner, deployment account, Region, state file, dependencies, and whether an equivalent Control Tower resource exists.

### Terraform state correction

The repository currently requires S3 plus DynamoDB locking. Current HashiCorp documentation states that S3 state locking is enabled with `use_lockfile = true` and that DynamoDB-based locking is deprecated. New implementation should therefore use an encrypted, versioned S3 backend with S3 lockfiles, subject to the selected Terraform version and bootstrap approval. See [HashiCorp S3 backend documentation](https://developer.hashicorp.com/terraform/language/backend/s3).

## 7. AFT decision

**Decision: do not deploy AFT in the initial implementation.** Use Control Tower Account Factory for the small, fixed initial account set, then establish Terraform execution roles and account baselines separately.

AFT becomes justified when all of the following are true:

- Account requests must be submitted and reviewed through Git.
- Account creation/update volume makes manual Account Factory operation an operational bottleneck.
- Global, OU-specific, and account-specific customizations require repeatable pipelines.
- A dedicated AFT management account, repository model, on-call ownership, and recurring cost are approved.
- The organization already has a working Control Tower landing zone.

AWS states that AFT requires an existing Control Tower landing zone and a separate AFT management account. AFT provisions and customizes accounts; it is not intended to deploy application workload resources. See [AFT overview](https://docs.aws.amazon.com/controltower/latest/userguide/aft-overview.html).

AFT can be added later without changing the initial Control Tower-first decision. Deferral avoids deploying CodeBuild, CodePipeline, Lambda, Step Functions, DynamoDB, S3, KMS, CloudWatch, VPC, and other AFT components before their operational value is demonstrated. See [AFT component services](https://docs.aws.amazon.com/controltower/latest/userguide/aft-components.html).

## 8. Recurring-cost considerations

No budget estimate is possible until account count, Regions, resource volumes, log retention, traffic, and support plan are supplied. A cost estimate and AWS Budgets alarms are required before the first approval to enable paid services.

| Service/capability | Recurring cost driver | Required decision/control |
|---|---|---|
| AWS Control Tower | No additional Control Tower charge; charges arise from enabled underlying services | Review the landing-zone service footprint and account/Region count; see [Control Tower pricing](https://docs.aws.amazon.com/controltower/latest/userguide/pricing.html) |
| Account Factory/Service Catalog | Provisioning and underlying service use as described by Control Tower pricing | Estimate per-account workflow and retained artifacts |
| AWS Config | Configuration items, rule evaluations, conformance packs, and aggregations; ephemeral resources can increase volume | Decide governed Regions, recording scope, rules, and retention; see [AWS Config pricing](https://aws.amazon.com/config/pricing/) |
| GuardDuty | Analyzed CloudTrail, VPC Flow Log, DNS, S3, Kubernetes, malware-protection, and other enabled data sources | Approve protection plans and Regions; monitor trial-to-paid transition; see [GuardDuty pricing](https://aws.amazon.com/guardduty/pricing/) |
| Security Hub | Security checks and finding ingestion/automation according to enabled capabilities | Approve standards, Regions, and aggregation; see [Security Hub pricing](https://aws.amazon.com/security-hub/pricing/) |
| CloudTrail | Additional trail copies, CloudTrail Lake ingestion/retention, Insights, and data events | Avoid duplicate trails; scope high-volume S3/Lambda data events; see [CloudTrail pricing](https://aws.amazon.com/cloudtrail/pricing/) |
| NAT Gateway | Gateway-hours and processed bytes; cross-AZ/data-transfer patterns can add cost | Decide none/single/per-AZ by environment and prefer VPC endpoints where justified; see [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/) |
| Transit Gateway | Attachments, processed data, peering, and network-manager features | Approve topology and route isolation before deployment; see [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/) |
| AWS KMS | Customer-managed keys, API requests, rotation, and imported/custom key options | Minimize unnecessary keys while preserving account boundaries; see [AWS KMS pricing](https://aws.amazon.com/kms/pricing/) |
| S3 log and state storage | Stored bytes, requests, retrieval, replication, lifecycle transitions, and early deletion | Define retention, storage classes, replication, and evidence access; see [Amazon S3 pricing](https://aws.amazon.com/s3/pricing/) |
| VPC Flow Logs | Destination ingestion/storage/query charges and traffic volume | Define filters, destination, retention, and query platform |
| CloudWatch | Log ingestion, storage, metrics, alarms, dashboards, and queries | Set retention explicitly and avoid unbounded AFT/application logs |
| AFT if adopted | Dedicated account plus AFT component-service execution and storage | Create a separate AFT estimate; CloudWatch logs defaulting to never expire require review |
| AWS Support | Organization/account support plan | Legal/billing owner must approve before optional AFT Enterprise Support enrollment |

## 9. Approval gates

An approval must name the approver, scope, target accounts/OUs/Regions, reviewed artifact, timestamp, rollback or recovery procedure, and evidence location. Silence or a merged code change is not deployment approval.

### Gate A — Architecture and prerequisites

Required before account creation or Control Tower setup:

- All REQUIRED identity, billing, account-email, organization, Region, and compliance inputs are resolved.
- Management-account root MFA, alternate contacts, and emergency access are confirmed.
- Existing Organizations, IAM Identity Center, Config, CloudTrail, SCP, and quota conflicts are assessed.
- OU model, account registry, cost estimate, and ownership boundary are approved.
- Approvers: cloud/platform owner, security owner, and billing/legal owner.

### Gate B — Account creation

Required before creating Audit, Log Archive, Shared Services, Development, Staging, Production, or AFT accounts:

- Unique monitored email, named owner, cost center, support plan, target OU, and recovery contact exist for every account.
- Organization account quota and payment method are verified.
- The exact account list and account-vending mechanism are approved.
- Approvers: organization administrator, security owner, and billing owner.

### Gate C — Control Tower landing-zone setup

Required immediately before setup:

- Home Region and governed Regions are explicitly approved.
- IAM Identity Center alignment and STS endpoints are validated.
- Audit/Log Archive account approach and existing organization behavior are reviewed.
- Pre-launch checks pass and the evidence/rollback runbook is ready.
- Approvers: organization administrator and security owner; production change record required.

### Gate D — Controls and SCP attachment

Required for each control/SCP rollout:

- Native Control Tower control mapping is completed first.
- Policy validation and exception paths are documented.
- Control Tower roles and global services are not blocked.
- The policy passes sandbox negative and positive tests.
- Rollout order is Sandbox, Development/Non-Production, Staging, then Production.
- Root attachment is prohibited for the initial rollout.
- Approvers: security owner and organization administrator; production owner for Production OU.

### Gate E — Terraform plan and apply

Required for every state and environment:

- `fmt`, `validate`, lint, security scan, and tests pass.
- The exact saved plan, execution role, account, Region, state key, resource ownership, cost delta, and rollback procedure are reviewed.
- Any replace/destroy action receives specific approval; a general apply approval is insufficient.
- Production apply runs only from the approved CI/CD environment with protected-branch and environment approval controls.
- Approvers: module owner and target-environment owner; security approval for IAM, SCP, logging, and security services.

`terraform apply` is not authorized by this document.

## 10. Irreversible or difficult-to-change decisions

| Decision | Risk and required treatment |
|---|---|
| Control Tower home Region | Cannot be changed after selection; resolve Identity Center and residency requirements first |
| One landing zone per organization | Existing landing-zone status must be checked before setup |
| Management account and organization boundary | Organization migration and management-account changes have broad billing, trust, and service-integration effects |
| Audit and Log Archive account identities | Account emails must be unique; account closure/replacement and evidence migration are disruptive |
| IAM Identity Center Region/source | Constrains Control Tower setup and human access; federation changes affect every account |
| OU hierarchy and inherited controls | Moving accounts or restructuring OUs changes inherited SCP/control behavior and can cause outages |
| Governed Regions | Can be updated, but landing-zone update plus OU/account re-registration is required; ungoverned does not mean denied |
| Region-deny exceptions | An incomplete global-service or Control Tower exception can block essential operations |
| Account email and root ownership | Difficult to recover if aliases, mailboxes, or named owners disappear |
| Terraform state location, key layout, encryption, and locking | Migration affects every pipeline and can cause split state or concurrent writes |
| KMS key ownership/deletion | Disabled or scheduled-deletion keys can make logs and state unreadable |
| S3 Object Lock and retention mode | Compliance retention can intentionally prevent deletion; legal and storage implications require separate approval |
| CIDR allocation and network topology | Overlap is expensive to remediate after routing, endpoints, and partner connectivity exist |
| NAT/TGW/central-egress architecture | Changes routes, failure domains, inspection paths, and recurring data-processing cost |
| AFT adoption | Adds a dedicated account, repositories, pipelines, state, and numerous component services; adopt only with operational ownership |
| Log retention and replication | Long retention/replication creates durable cost; insufficient retention creates audit risk |

## 11. Unresolved-input checklist

- [ ] REQUIRED: Confirm commercial AWS partition or identify the required partition.
- [ ] REQUIRED: Provide management account ID, email, named owner, billing owner, and alternate contacts.
- [ ] REQUIRED: Confirm whether an AWS Organization already exists and provide its ID and current OU/account inventory.
- [ ] REQUIRED: Confirm whether a Control Tower landing zone already exists.
- [ ] REQUIRED: Record existing IAM Identity Center Region and identity source.
- [ ] REQUIRED: Approve or replace proposed home Region `eu-west-1`.
- [ ] REQUIRED: Approve governed Regions; confirm whether `eu-west-2` is required.
- [ ] REQUIRED: Provide data-residency, regulatory, and service-availability requirements.
- [ ] REQUIRED: Provide unique monitored emails, owners, cost centers, and target OUs for all seven required accounts.
- [ ] Decide whether a Sandbox account is required initially.
- [ ] Confirm AFT remains deferred; if not, provide the repeatable GitOps account-vending requirement and AFT account details.
- [ ] REQUIRED: Select the support plan and approve the recurring-cost envelope.
- [ ] REQUIRED: Approve the stricter Security/Infrastructure/Non-Production/Production/Sandbox OU model.
- [ ] REQUIRED: Identify platform, security, network, production, and billing approvers.
- [ ] REQUIRED: Confirm IAM Identity Center user store or name the external IdP and access-review process.
- [ ] REQUIRED: Select and pin Terraform and AWS provider versions.
- [ ] REQUIRED: Define the Terraform state account, bucket, Region, key layout, KMS policy, recovery owners, and bootstrap process.
- [ ] Approve S3 lockfile state locking and retire the repository's new-build DynamoDB-locking requirement.
- [ ] REQUIRED: Confirm GitHub Actions or name the CI/CD platform and repository identity for OIDC trust.
- [ ] REQUIRED: Approve log/evidence retention, storage classes, replication, and optional Object Lock requirements.
- [ ] REQUIRED: Validate example CIDRs against enterprise IPAM, on-premises, partner, VPN, Direct Connect, and acquired networks.
- [ ] REQUIRED: Decide NAT strategy separately for development, staging, and production.
- [ ] REQUIRED: Decide whether Transit Gateway, centralized egress, network inspection, and shared private DNS are in initial scope.
- [ ] REQUIRED: Select GuardDuty protection plans, Security Hub standards, Config scope, CloudTrail data events, and enabled Regions after cost estimation.
- [ ] REQUIRED: Define budget thresholds, alert recipients, and cost-anomaly ownership before enabling paid services.
- [ ] REQUIRED: Approve Gates A through E and their named approvers before any mutating deployment step.

## Official references

- [Plan your AWS Control Tower landing zone](https://docs.aws.amazon.com/controltower/latest/userguide/planning-your-deployment.html)
- [AWS Control Tower pre-launch checks](https://docs.aws.amazon.com/controltower/latest/userguide/getting-started-prereqs.html)
- [How AWS Regions work with AWS Control Tower](https://docs.aws.amazon.com/controltower/latest/userguide/region-how.html)
- [AWS Control Tower pricing](https://docs.aws.amazon.com/controltower/latest/userguide/pricing.html)
- [AFT overview](https://docs.aws.amazon.com/controltower/latest/userguide/aft-overview.html)
- [AFT component services](https://docs.aws.amazon.com/controltower/latest/userguide/aft-components.html)
- [HashiCorp Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3)
- [AWS Config pricing](https://aws.amazon.com/config/pricing/)
- [Amazon GuardDuty pricing](https://aws.amazon.com/guardduty/pricing/)
- [AWS Security Hub pricing](https://aws.amazon.com/security-hub/pricing/)
- [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/)
- [AWS CloudTrail pricing](https://aws.amazon.com/cloudtrail/pricing/)
- [AWS KMS pricing](https://aws.amazon.com/kms/pricing/)
- [Amazon S3 pricing](https://aws.amazon.com/s3/pricing/)
