# Skill 11 — AWS Control Tower Landing Zone

## Skill Purpose
Use AWS Control Tower as the preferred enterprise accelerator for building and governing a secure multi-account AWS landing zone, then extend it with Terraform and Account Factory for Terraform where required.

AWS Control Tower should not be treated as a replacement for AWS Organizations, IAM, CloudTrail, AWS Config, SCPs, networking, or Terraform. It orchestrates and governs many of these capabilities so that the baseline is more consistent and easier to operate.

---

## Where This Skill Fits in the Project

Use this skill before or alongside the AWS Organizations skill.

Recommended order:

```text
Control Tower planning
→ Management account readiness
→ Landing zone setup
→ Log Archive and Audit/Security account baseline
→ OU design
→ Account Factory or AFT account provisioning
→ Control selection
→ Terraform extension modules
→ Validation and evidence
```

---

## What You Must Know

- What AWS Control Tower does
- What a Control Tower landing zone is
- Relationship between AWS Control Tower and AWS Organizations
- Log Archive account pattern
- Audit/Security account pattern
- Account Factory
- Account Factory for Terraform
- Enrolled OUs and governed accounts
- Mandatory controls
- Optional controls
- Preventive controls
- Detective controls
- Proactive controls
- Control Tower lifecycle updates
- Drift detection and remediation
- Where Terraform should and should not manage resources

---

## Control Tower Role in This Project

For this project, AWS Control Tower is the recommended production-grade way to establish the initial landing zone.

Control Tower should be used for:

- Creating or governing the landing zone baseline
- Managing the multi-account foundation
- Establishing Log Archive and Audit/Security accounts
- Applying standard governance controls
- Provisioning accounts through Account Factory
- Enrolling OUs under governance
- Providing a consistent account baseline
- Reducing manual setup of organization-level governance

Terraform should then be used for:

- Custom VPC and networking modules
- Transit Gateway or shared services connectivity
- Additional SCPs where Control Tower controls are not enough
- Cross-account IAM roles
- Security service configuration
- Workload account baselines
- CI/CD integration
- Validation scripts
- Documentation and evidence automation

---

## Control Tower vs Manual AWS Organizations

| Area | Control Tower approach | Manual Organizations approach |
|---|---|---|
| Landing zone setup | AWS-managed baseline | Custom Terraform setup |
| Account creation | Account Factory or AFT | `aws_organizations_account` |
| Logging baseline | Log Archive account pattern | Custom CloudTrail and S3 setup |
| Security account | Audit/Security account pattern | Custom delegated admin setup |
| Guardrails | Control Tower controls | Custom SCPs and Config rules |
| Drift visibility | Control Tower drift awareness | Terraform drift checks only |
| Best for | Enterprise production | Lab, portfolio, or custom environments |

For a real enterprise project, prefer Control Tower unless there is a strong reason not to use it.

---

## Recommended Control Tower Account Model

```text
Management Account
├── AWS Control Tower home Region
├── AWS Organizations administration
├── IAM Identity Center / federation
└── Account Factory / landing zone administration

Security / Audit Account
├── GuardDuty delegated admin
├── Security Hub delegated admin
├── IAM Access Analyzer
├── AWS Config aggregation, where required
└── Incident response roles

Log Archive Account
├── Central CloudTrail logs
├── Config logs, where required
├── VPC Flow Logs archive
├── Log retention and lifecycle policies
└── Auditor read-only access

Shared Services Account
├── Transit Gateway or network hub
├── Shared DNS
├── Shared CI/CD tools
├── Artifact repositories
└── Shared observability tooling

Development Account
├── Developer workloads
├── Module testing
└── Non-production data only

Staging Account
├── Production-like validation
├── Integration and release testing
└── Security validation

Production Account
├── Live workloads
├── Strict controls
├── Restricted access
└── Mandatory logging and monitoring

AFT Management Account, optional
├── AFT pipelines
├── Account request workflow
├── Global customizations
└── Account-specific customizations
```

---

## Recommended OU Model

```text
Root
├── Security OU
│   ├── Security / Audit Account
│   └── Log Archive Account
├── Infrastructure OU
│   ├── Shared Services Account
│   └── AFT Management Account, optional
├── Workloads OU
│   ├── Development Account
│   ├── Staging Account
│   └── Production Account
└── Sandbox OU
    └── Experimental accounts
```

Alternative when production requires stricter controls:

```text
Root
├── Security
├── Infrastructure
├── Non-Production
├── Production
└── Sandbox
```

---

## Implementation Tasks

### Phase 1 — Plan Control Tower

1. Confirm the AWS management account.
2. Select the Control Tower home Region.
3. Define governed Regions.
4. Define OU structure.
5. Define Log Archive account.
6. Define Audit/Security account.
7. Decide whether Account Factory alone is enough or whether AFT is required.
8. Document constraints and assumptions.

### Phase 2 — Establish the landing zone

1. Enable AWS Control Tower.
2. Configure identity integration through IAM Identity Center or federation.
3. Create or enroll Log Archive and Audit/Security accounts.
4. Create the initial OU structure.
5. Confirm baseline logging and governance.
6. Record screenshots or CLI evidence.

### Phase 3 — Provision accounts

1. Use Account Factory for basic account vending.
2. Use AFT if Terraform-based account requests and customizations are required.
3. Create or enroll:
   - Development account
   - Staging account
   - Production account
   - Shared services account
   - Optional AFT management account
4. Apply account baselines.
5. Tag accounts and document ownership.

### Phase 4 — Apply controls

1. Review mandatory controls.
2. Enable strongly recommended controls where appropriate.
3. Enable selected optional controls based on project requirements.
4. Map project guardrails to Control Tower controls.
5. Create custom SCPs only for gaps.
6. Test controls first in sandbox or development.
7. Record denial evidence.

### Phase 5 — Extend with Terraform

1. Create Terraform modules for custom infrastructure.
2. Avoid overwriting Control Tower-owned baseline resources.
3. Deploy custom IAM roles.
4. Deploy networking standards.
5. Deploy security service configuration.
6. Deploy shared services infrastructure.
7. Configure CI/CD validation.

### Phase 6 — Validate and document

1. Validate Control Tower landing zone status.
2. Validate governed OUs.
3. Validate account enrollment.
4. Validate log delivery.
5. Validate controls.
6. Validate cross-account access.
7. Validate Terraform plans.
8. Store evidence under `docs/evidence/`.

---

## Account Factory and AFT Decision Guide

Use **Account Factory** when:

- Account creation is occasional.
- You are comfortable with console-driven or standard account provisioning.
- Account customizations are limited.
- The organization does not require a full GitOps account vending workflow.

Use **Account Factory for Terraform** when:

- Account creation must be managed through Terraform.
- You need repeatable account requests.
- You need account-specific customizations.
- You need a Git-based approval workflow.
- You want Terraform account provisioning while staying governed by Control Tower.

---

## Terraform Ownership Rules

Do not use Terraform blindly against resources created and owned by Control Tower.

Follow this ownership model:

| Resource type | Preferred owner |
|---|---|
| Control Tower landing zone baseline | AWS Control Tower |
| Mandatory Control Tower resources | AWS Control Tower |
| Account vending through AFT | AFT pipeline / Terraform |
| Custom VPCs | Terraform |
| Custom IAM roles | Terraform |
| Custom SCPs | Terraform, if not covered by Control Tower |
| Shared services networking | Terraform |
| Workload baselines | Terraform |
| Evidence scripts | Terraform/scripts/CI pipeline |

If a resource is created by Control Tower, do not import and manage it in Terraform unless the team has documented ownership and lifecycle impact.

---

## Control and Guardrail Mapping

| Project requirement | Control Tower first | Terraform/custom extension |
|---|---|---|
| Central log archive | Use Control Tower Log Archive account baseline | Add lifecycle, access, and evidence checks |
| Security account | Use Audit/Security account baseline | Add delegated admin and incident roles |
| Prevent CloudTrail tampering | Use Control Tower controls where available | Add custom SCP if needed |
| Restrict Regions | Use Region controls where appropriate | Add SCP exception model |
| Detect public S3 exposure | Use detective/proactive controls | Add S3 Public Access Block and SCP |
| Account vending | Use Account Factory | Use AFT for GitOps/Terraform workflow |
| Security visibility | Use Control Tower + Security Hub/GuardDuty | Add centralized aggregation modules |
| Network standards | Not fully handled by Control Tower | Use Terraform VPC/TGW modules |

---

## Validation Checks

### Control Tower status

```bash
aws controltower list-landing-zones
```

### AWS Organizations accounts

```bash
aws organizations list-accounts
aws organizations list-roots
aws organizations list-organizational-units-for-parent --parent-id <ROOT_ID>
```

### Control Tower controls

```bash
aws controltower list-enabled-controls --target-identifier <OU_ARN>
```

### Account enrollment evidence

```bash
aws organizations list-accounts-for-parent --parent-id <OU_ID>
```

### CloudTrail evidence

```bash
aws cloudtrail describe-trails --include-shadow-trails
aws cloudtrail get-trail-status --name <TRAIL_NAME>
aws s3 ls s3://<LOG_ARCHIVE_BUCKET>/AWSLogs/ --recursive | head
```

### Terraform drift evidence

```bash
terraform plan -detailed-exitcode
```

---

## Common Mistakes

- Treating Control Tower as optional in an enterprise landing zone without documenting why.
- Trying to manage Control Tower-owned resources directly in Terraform.
- Creating custom SCPs that break Control Tower service-linked roles.
- Forgetting that Control Tower uses AWS Organizations underneath.
- Not separating the management account from workload accounts.
- Not validating whether OUs are governed.
- Not documenting which controls are native Control Tower controls and which are custom.
- Using Account Factory manually when the requirement needs a GitOps/Terraform workflow.
- Deploying shared services or workloads into the management account.
- Assuming Control Tower replaces the need for clear IAM, networking, logging, and Terraform standards.

---

## Interview Talking Point

> I used AWS Control Tower as the preferred production landing zone accelerator because it provides a governed multi-account baseline using AWS Organizations, log archive and audit/security account patterns, account vending, and governance controls. I then extended that baseline with Terraform modules for custom IAM roles, networking, security service configuration, additional SCPs, and CI/CD validation. This gave me the best of both approaches: AWS-managed governance for the foundation and infrastructure-as-code for customization and repeatability.

---

## Definition of Done

This skill is complete when:

- The Control Tower adoption decision is documented.
- The management, log archive, audit/security, shared services, dev, staging, and production accounts are mapped.
- The OU structure is documented.
- Account Factory or AFT decision is documented.
- Control Tower controls are mapped to project guardrails.
- Custom Terraform modules extend, but do not conflict with, the Control Tower baseline.
- Validation evidence proves that governance, logging, and account placement are working.
