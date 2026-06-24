# AGENTS.md — Multi-Account AWS Landing Zone with AWS Control Tower and Terraform

## Project Name
Production-Grade Multi-Account AWS Landing Zone using AWS Control Tower, AWS Organizations, IAM Identity Center, Centralized Logging, Guardrails, Account Factory, AFT, Networking Standards, and Terraform Modules.

## Project Objective
Design and implement a secure, governed, repeatable AWS landing zone using separate AWS accounts for development, staging, production, security, logging, and shared services.

The preferred enterprise implementation path is **AWS Control Tower first**, extended with **Terraform modules** and, where appropriate, **AWS Control Tower Account Factory for Terraform (AFT)**.

The project must support two implementation modes:

1. **Control Tower-first implementation — recommended for production**
   - Use AWS Control Tower to establish the landing zone baseline.
   - Use AWS Organizations underneath Control Tower.
   - Use Account Factory or AFT for account provisioning.
   - Use Control Tower controls for preventive, detective, and proactive governance.
   - Use Terraform to extend the landing zone with custom networking, IAM, security, observability, SCPs, and workload baselines.

2. **Manual AWS Organizations implementation — acceptable for portfolio/lab environments**
   - Use AWS Organizations, Terraform, custom SCPs, centralized CloudTrail, IAM roles, and account baselines directly.
   - Clearly document why Control Tower was not used, for example cost, lab constraints, lack of enterprise AWS Organization, or learning objective.

The final outcome should demonstrate senior-level understanding of AWS governance, account isolation, centralized auditability, secure access, repeatable infrastructure, and operational validation.

---

## Architecture Summary

This project establishes a secure, scalable, and repeatable AWS foundation for enterprise workloads.

### Preferred Landing Zone Flow

```text
AWS Management Account
        |
        |  Enable AWS Control Tower landing zone
        v
AWS Control Tower
        |
        |-- AWS Organizations
        |-- IAM Identity Center / federated access
        |-- Log Archive account
        |-- Audit / Security account
        |-- Account Factory
        |-- Controls / guardrails
        |
        |  Extend with Terraform / AFT
        v
Custom Platform Baselines
        |
        |-- Shared services networking
        |-- Additional SCPs
        |-- IAM cross-account roles
        |-- Security services
        |-- VPC standards
        |-- CI/CD and validation
```

### Core AWS Services

- AWS Control Tower
- AWS Control Tower Account Factory
- AWS Control Tower Account Factory for Terraform, where appropriate
- AWS Organizations
- Organizational Units
- AWS IAM Identity Center or external identity federation
- AWS IAM and AWS STS
- IAM cross-account roles
- Service Control Policies
- AWS Control Tower controls: preventive, detective, and proactive
- AWS CloudTrail organization trail
- AWS Config
- Amazon S3 for centralized log archive
- AWS KMS for encryption
- Amazon GuardDuty
- AWS Security Hub
- IAM Access Analyzer
- Amazon VPC
- VPC Flow Logs
- AWS Transit Gateway or shared networking pattern
- Route 53 private hosted zones where required
- AWS Systems Manager for operational access where required
- Terraform
- Terraform remote state using S3 and DynamoDB
- CI/CD pipeline for infrastructure changes

---

## Target Account Structure

### 1. Management Account
Purpose: Organization and Control Tower administration only.

Rules:

- Do not run workloads here.
- Use this account for AWS Control Tower setup, AWS Organizations administration, billing, SCPs, account vending, and organization-level integrations.
- Restrict access to a very small number of trusted administrators.
- Require MFA and federation for privileged users.
- Avoid routine manual changes.

### 2. Security / Audit Account
Purpose: Central security operations and delegated security administration.

Responsibilities:

- GuardDuty delegated administrator
- Security Hub delegated administrator
- IAM Access Analyzer administration
- AWS Config aggregation where required
- Incident response roles
- Security automation
- Security dashboards and findings review

In AWS Control Tower, this often maps to the Audit account pattern.

### 3. Logging / Log Archive Account
Purpose: Protected central log storage.

Responsibilities:

- Central CloudTrail logs
- VPC Flow Logs archive
- AWS Config delivery buckets, where required
- S3 access logging where applicable
- KMS keys for log encryption
- Retention and lifecycle policies
- Read-only access for auditors and security teams

In AWS Control Tower, this maps to the Log Archive account pattern.

### 4. Shared Services Account
Purpose: Shared infrastructure consumed by workload accounts.

Responsibilities:

- Central networking services
- Transit Gateway or network hub
- Shared DNS
- CI/CD tooling where required
- Artifact repositories
- Shared observability tooling
- Centralized egress pattern where required
- SSM operational access pattern where required

### 5. Development Account
Purpose: Development workloads and controlled experimentation.

Rules:

- No production data.
- Lower-cost infrastructure may be allowed.
- Controlled experimentation is allowed inside guardrails.
- Used for Terraform module testing before staging.

### 6. Staging Account
Purpose: Production-like pre-release environment.

Rules:

- Mirrors production as closely as practical.
- Used for release validation, security checks, performance tests, and integration tests.
- Guardrails should be close to production.

### 7. Production Account
Purpose: Live customer-facing workloads.

Rules:

- Strict change control.
- Restricted privileged access.
- Mandatory monitoring, logging, encryption, backups, and alerting.
- No direct manual changes except documented break-glass scenarios.

### Optional 8. AFT Management Account
Purpose: Dedicated account for AWS Control Tower Account Factory for Terraform.

Responsibilities:

- Host AFT pipelines.
- Manage account request workflows.
- Apply global and account-specific customizations.
- Integrate Terraform-based account provisioning with Control Tower governance.

Do not mix AFT management workloads with production application workloads.

---

## Recommended Organizational Unit Structure

### Control Tower-friendly OU model

```text
Root
├── Security OU
│   ├── Security / Audit Account
│   └── Logging / Log Archive Account
├── Infrastructure OU
│   ├── Shared Services Account
│   └── AFT Management Account, optional
├── Workloads OU
│   ├── Development Account
│   ├── Staging Account
│   └── Production Account
└── Sandbox OU
    └── Optional experimental accounts
```

### Alternative stricter OU model

```text
Root
├── Security
├── Infrastructure
├── Non-Production
│   ├── Development
│   └── Staging
├── Production
└── Sandbox
```

Use the stricter model when production requires separate SCPs, separate approval processes, and tighter Region or service restrictions than non-production.

---

## Implementation Strategy

### Recommended production strategy

```text
1. Plan landing zone design.
2. Prepare management account.
3. Enable AWS Control Tower.
4. Configure IAM Identity Center or identity federation.
5. Create or enroll Log Archive and Security/Audit accounts.
6. Create OUs.
7. Provision accounts using Account Factory or AFT.
8. Apply mandatory and strongly recommended Control Tower controls.
9. Add custom SCPs only where Control Tower controls do not meet the requirement.
10. Extend baseline with Terraform modules.
11. Deploy networking and shared services.
12. Enable security services and aggregation.
13. Validate controls and collect evidence.
14. Document operating model and handover.
```

### Lab or portfolio strategy

```text
1. Document that Control Tower is the preferred enterprise option.
2. Implement equivalent concepts manually using AWS Organizations and Terraform.
3. Create OUs, accounts, SCPs, CloudTrail, IAM roles, logging, and networking modules.
4. Include a Control Tower migration or adoption section in the documentation.
5. Explain trade-offs clearly in the README and interview explanation.
```

---

## Agent Roles and Responsibilities

### 1. Landing Zone Architect Agent
Owns the overall architecture and target operating model.

Responsibilities:

- Define the account model.
- Decide whether to use Control Tower-first, manual Organizations-first, or hybrid implementation.
- Define OU structure.
- Confirm workload separation.
- Ensure the management account is not used for workloads.
- Align design with AWS Well-Architected principles.
- Produce architecture diagrams and decision records.
- Document trade-offs between Control Tower and custom Terraform implementation.

Done when:

- Account model is documented.
- OU model is documented.
- Control Tower usage decision is documented.
- Control plane and workload responsibilities are clearly separated.
- Environment promotion path is clear: development → staging → production.

---

### 2. AWS Control Tower Agent
Owns AWS Control Tower setup, landing zone configuration, Account Factory, enrolled OUs, controls, and Control Tower lifecycle.

Responsibilities:

- Plan Control Tower deployment prerequisites.
- Confirm landing zone Region and supported Regions.
- Set up or validate Log Archive and Audit/Security accounts.
- Configure IAM Identity Center or identity federation.
- Create or enroll OUs into Control Tower governance.
- Provision accounts using Account Factory.
- Use AFT where Terraform-based account provisioning and customization is required.
- Enable mandatory, strongly recommended, and selected optional controls.
- Track drift and lifecycle updates.
- Document which controls are native Control Tower controls and which are custom SCPs.

Required design decisions:

- Which account is used as the management account.
- Which account is the log archive account.
- Which account is the audit/security account.
- Whether AFT is required.
- Which OUs are enrolled in Control Tower.
- Which Regions are governed.
- Which Control Tower controls are enabled.
- Which controls require custom Terraform/SCP implementation.

Done when:

- Control Tower landing zone is enabled or clearly documented as a planned enterprise pattern.
- OUs are governed or prepared for governance.
- Log archive and audit/security accounts are in place.
- Account vending process is documented.
- Control Tower controls are mapped to project guardrails.
- AFT decision is documented.

---

### 3. AWS Organizations and Governance Agent
Owns AWS Organizations, account placement, delegated administrators, and custom guardrails.

Responsibilities:

- Define AWS Organizations structure.
- Create or validate OUs.
- Create, invite, or enroll member accounts.
- Configure delegated administrator accounts for security services.
- Write and apply custom SCPs where Control Tower controls do not cover the requirement.
- Avoid duplicating Control Tower managed controls unless necessary.
- Prevent dangerous activity such as disabling CloudTrail, deleting log buckets, leaving the organization, or using unauthorized Regions.

Required guardrails:

- Deny disabling CloudTrail.
- Deny deleting centralized log buckets.
- Deny leaving AWS Organizations.
- Deny creating resources outside approved Regions.
- Deny public S3 buckets unless explicitly approved.
- Deny root user routine usage where practical.
- Deny IAM users where federation is required.
- Deny privilege escalation actions except from approved roles.
- Deny disabling GuardDuty, Security Hub, or AWS Config where enabled.

Done when:

- OUs are created or enrolled.
- Accounts are assigned to correct OUs.
- Native Control Tower controls and custom SCPs are documented separately.
- SCPs are attached and tested safely.
- Delegated administration is configured.
- Guardrail test evidence is recorded.

---

### 4. IAM and Access Control Agent
Owns identity, roles, permissions, permission boundaries, and access review.

Responsibilities:

- Prefer IAM Identity Center or external identity provider federation.
- Define cross-account IAM roles.
- Enforce least privilege.
- Define admin, read-only, security-audit, network-admin, pipeline, incident response, and break-glass roles.
- Require MFA for privileged access.
- Avoid long-lived access keys.
- Create permission boundaries where appropriate.
- Document access review process.

Required roles:

- OrganizationAdminRole
- SecurityAuditRole
- NetworkAdminRole
- TerraformExecutionRole
- ReadOnlyRole
- IncidentResponseRole
- BreakGlassAdminRole
- AFTExecutionRole, where AFT is used

Done when:

- Cross-account roles are created.
- Trust policies are explicit.
- Permission boundaries are applied where required.
- MFA and federation requirements are documented.
- Access review process is defined.

---

### 5. Centralized Logging and Audit Agent
Owns CloudTrail, log archive, retention, encryption, and audit readiness.

Responsibilities:

- Use Control Tower log archive baseline where Control Tower is enabled.
- Validate organization-level CloudTrail logging.
- Deliver logs to the logging/log archive account.
- Encrypt logs using KMS where configured.
- Enable CloudTrail log file validation where applicable.
- Configure S3 bucket versioning.
- Configure object lock where required.
- Configure lifecycle policies.
- Centralize VPC Flow Logs.
- Centralize AWS Config delivery where applicable.
- Restrict write access to logging buckets.

Done when:

- Organization trail is active or Control Tower baseline logging is verified.
- Logs from all governed accounts arrive in the log archive bucket.
- Member accounts cannot disable or delete the organization trail.
- Log bucket policy allows only approved AWS services and security roles.
- Retention and lifecycle policies are documented.

---

### 6. Security Baseline Agent
Owns security services and default baseline configuration.

Responsibilities:

- Enable GuardDuty across accounts.
- Enable Security Hub across accounts.
- Enable AWS Config where required.
- Configure IAM Access Analyzer.
- Configure default encryption standards.
- Define detective controls.
- Define incident response access.
- Integrate Control Tower detective/proactive controls where appropriate.

Done when:

- Security services are enabled in approved Regions.
- Delegated admin is configured from the security account.
- Findings are aggregated centrally.
- Baseline security controls are documented and tested.

---

### 7. Networking Standards Agent
Owns network design, IP addressing, routing, shared services connectivity, and flow logs.

Responsibilities:

- Define CIDR allocation strategy.
- Create VPC standards for development, staging, production, shared services, security, and logging.
- Define public, private, and isolated subnet patterns.
- Define routing standards.
- Define NAT Gateway and egress standards.
- Define Transit Gateway or VPC peering strategy.
- Define shared DNS standards.
- Enable VPC Flow Logs.
- Define security group and NACL standards.

Minimum standards:

- No overlapping CIDR ranges.
- Multi-AZ subnet design for production.
- Private workloads must not be directly exposed to the internet.
- Public subnet use must be limited to load balancers, NAT gateways, and approved edge services.
- VPC Flow Logs must be enabled for audit and troubleshooting.
- Network routes must be documented.
- Production should not have unrestricted east-west connectivity to non-production.

Done when:

- IP plan is documented.
- VPC module is reusable.
- Dev, staging, and production networks follow the same pattern.
- Shared services connectivity is validated.
- Flow logs are delivered to central logging.

---

### 8. Terraform Infrastructure Agent
Owns Terraform module design, remote state, provider configuration, and reusable infrastructure patterns.

Responsibilities:

- Build reusable Terraform modules.
- Configure remote state.
- Use account-specific provider aliases.
- Use explicit tagging standards.
- Validate Terraform formatting and linting.
- Separate organization/global resources from account-level resources.
- Avoid managing Control Tower-owned resources directly unless the resource ownership is clearly documented.
- Use AFT for account provisioning/customization where Control Tower + Terraform integration is required.
- Prevent hardcoded account IDs, secrets, and credentials.

Required modules:

- control-tower-baseline or control-tower-configuration-documentation
- aft-account-request, where AFT is used
- organizations
- organizational-units
- account-baseline
- iam-cross-account-roles
- scp-guardrails
- cloudtrail-organization
- log-archive-bucket
- security-baseline
- vpc-standard
- transit-gateway or network-hub
- shared-dns
- terraform-state-backend

Done when:

- Modules are reusable.
- Environment configurations are separate.
- Terraform state is remote and locked.
- Terraform plan is reviewed before apply.
- Control Tower-owned resources are not accidentally overwritten.
- No secrets are committed.

---

### 9. CI/CD and Change Management Agent
Owns infrastructure delivery workflow.

Responsibilities:

- Define branch strategy.
- Run Terraform fmt, validate, lint, plan, and security checks.
- Require approval before production apply.
- Store plan artifacts.
- Prevent direct production changes from local machines.
- Enforce pull request review.
- Integrate AFT pipeline workflow where AFT is used.
- Keep Control Tower changes, Terraform changes, and account requests auditable.

Recommended pipeline stages:

```text
Checkout
→ Terraform fmt
→ Terraform validate
→ TFLint
→ Checkov / tfsec
→ Terraform plan
→ Manual approval for staging or production
→ Terraform apply or AFT account request merge
→ Post-deployment validation
→ Evidence upload
```

Done when:

- CI/CD pipeline is documented.
- Production changes require approval.
- Failed validation blocks merge or deployment.
- Deployment evidence is stored.
- Account provisioning changes are traceable.

---

### 10. Validation and Testing Agent
Owns proof that the landing zone works as expected.

Responsibilities:

- Validate Control Tower landing zone status where applicable.
- Validate governed OUs.
- Validate account structure.
- Validate Control Tower controls and custom SCP enforcement.
- Validate CloudTrail log delivery.
- Validate cross-account role assumption.
- Validate networking routes.
- Validate VPC Flow Logs.
- Validate Security Hub and GuardDuty aggregation.
- Validate Terraform drift detection.
- Record exceptions and remediation actions.

Required validation evidence:

- Control Tower landing zone status or documented manual equivalent.
- Governed OU/account list.
- Screenshot or CLI output showing accounts and OUs.
- Control/SCP denial test result.
- CloudTrail event found in central S3 bucket.
- Cross-account role assumption success.
- Terraform plan showing no drift after deployment.
- Security service aggregation dashboard.

Done when:

- All tests pass.
- Validation evidence is stored under `docs/evidence/`.
- Known exceptions are documented.

---

### 11. Documentation and Handover Agent
Owns project documentation, diagrams, runbooks, operating model, and interview-ready explanation.

Responsibilities:

- Maintain README.
- Maintain architecture diagrams.
- Maintain decision records.
- Maintain Control Tower adoption notes.
- Maintain Terraform workflow documentation.
- Maintain runbooks.
- Maintain onboarding guide.
- Maintain troubleshooting guide.
- Write interview explanation of the project.

Required documents:

- README.md
- architecture.md
- control-tower-landing-zone.md
- account-structure.md
- guardrails.md
- networking-standard.md
- terraform-workflow.md
- runbook.md
- validation-evidence.md
- interview-explanation.md

Done when:

- A new engineer can understand and deploy the project from documentation.
- The project can be explained clearly in an interview.
- Known trade-offs are documented.
- The Control Tower versus custom Terraform design decision is clear.

---

## Repository Structure

```text
aws-multi-account-landing-zone/
├── AGENTS.md
├── README.md
├── docs/
│   ├── architecture.md
│   ├── control-tower-landing-zone.md
│   ├── account-structure.md
│   ├── guardrails.md
│   ├── networking-standard.md
│   ├── terraform-workflow.md
│   ├── runbook.md
│   ├── validation-evidence.md
│   └── interview-explanation.md
├── infra/
│   ├── modules/
│   │   ├── control-tower-baseline/
│   │   ├── aft-account-request/
│   │   ├── organizations/
│   │   ├── organizational-units/
│   │   ├── account-baseline/
│   │   ├── iam-cross-account-roles/
│   │   ├── scp-guardrails/
│   │   ├── cloudtrail-organization/
│   │   ├── log-archive-bucket/
│   │   ├── security-baseline/
│   │   ├── vpc-standard/
│   │   ├── transit-gateway/
│   │   ├── shared-dns/
│   │   └── terraform-state-backend/
│   ├── environments/
│   │   ├── bootstrap/
│   │   ├── organization/
│   │   ├── control-tower/
│   │   ├── aft/
│   │   ├── security/
│   │   ├── logging/
│   │   ├── shared-services/
│   │   ├── development/
│   │   ├── staging/
│   │   └── production/
│   └── policies/
│       ├── scp/
│       ├── iam/
│       └── bucket-policies/
├── scripts/
│   ├── validate-control-tower.sh
│   ├── validate-organization.sh
│   ├── validate-cloudtrail.sh
│   ├── validate-scp.sh
│   ├── assume-role.sh
│   ├── validate-networking.sh
│   └── drift-check.sh
├── skills/
│   ├── README.md
│   ├── 01-aws-organizations-and-account-strategy.md
│   ├── 02-iam-cross-account-access.md
│   ├── 03-centralized-logging-cloudtrail.md
│   ├── 04-guardrails-and-scp.md
│   ├── 05-networking-standards.md
│   ├── 06-terraform-modules-and-state.md
│   ├── 07-security-baseline.md
│   ├── 08-cicd-and-change-management.md
│   ├── 09-validation-and-audit-evidence.md
│   ├── 10-interview-explanation.md
│   └── 11-aws-control-tower-landing-zone.md
└── .github/
    └── workflows/
        └── terraform.yml
```

---

## Terraform Standards

### General Rules

- Use modules for repeatable resources.
- Use separate state files per account and environment.
- Use remote state in S3 with DynamoDB locking.
- Use provider aliases for cross-account deployment.
- Never hardcode credentials.
- Never commit `.tfstate`, `.tfvars` containing secrets, or AWS credentials.
- Run `terraform fmt` before committing.
- Run `terraform validate` before creating a pull request.
- Use tags consistently.
- Do not import or modify Control Tower-owned resources unless ownership and lifecycle are clearly documented.
- Use AFT or approved account request workflows for account vending where Control Tower is adopted.

### Required Tags

```hcl
tags = {
  Project     = "multi-account-landing-zone"
  Environment = var.environment
  Owner       = "platform-team"
  ManagedBy   = "terraform"
  CostCenter  = var.cost_center
}
```

### State Layout

```text
s3://company-terraform-state/org/terraform.tfstate
s3://company-terraform-state/control-tower/terraform.tfstate
s3://company-terraform-state/aft/terraform.tfstate
s3://company-terraform-state/security/terraform.tfstate
s3://company-terraform-state/logging/terraform.tfstate
s3://company-terraform-state/shared-services/terraform.tfstate
s3://company-terraform-state/development/terraform.tfstate
s3://company-terraform-state/staging/terraform.tfstate
s3://company-terraform-state/production/terraform.tfstate
```

---

## Control Tower Controls and Custom SCP Standards

### Control categories

Control Tower controls should be mapped as:

- **Preventive controls**: block non-compliant actions, commonly using AWS Organizations policy mechanisms.
- **Detective controls**: detect non-compliance after deployment, commonly using AWS Config rules.
- **Proactive controls**: check resources before deployment where supported.

### Project guardrail mapping

| Requirement | Preferred implementation | Custom fallback |
|---|---|---|
| Protect CloudTrail | Control Tower baseline + custom SCP if needed | Custom SCP |
| Protect log archive | Control Tower Log Archive + bucket policy | Custom bucket policy + SCP |
| Restrict Regions | Control Tower Region controls where suitable | Custom SCP |
| Block public S3 | Control Tower controls + S3 Block Public Access | Custom SCP / AWS Config |
| Govern account vending | Account Factory / AFT | Terraform `aws_organizations_account` |
| Detect drift | Control Tower drift + Terraform plans | Terraform drift checks |
| Security findings | Security Hub / GuardDuty delegated admin | Account-level security modules |

### Minimum custom SCP examples

#### Deny disabling CloudTrail

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyCloudTrailTampering",
      "Effect": "Deny",
      "Action": [
        "cloudtrail:DeleteTrail",
        "cloudtrail:StopLogging",
        "cloudtrail:UpdateTrail"
      ],
      "Resource": "*"
    }
  ]
}
```

#### Deny leaving the organization

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyLeavingOrganization",
      "Effect": "Deny",
      "Action": [
        "organizations:LeaveOrganization"
      ],
      "Resource": "*"
    }
  ]
}
```

#### Restrict approved Regions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnapprovedRegions",
      "Effect": "Deny",
      "NotAction": [
        "iam:*",
        "organizations:*",
        "route53:*",
        "cloudfront:*",
        "waf:*",
        "support:*",
        "billing:*",
        "controltower:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": [
            "eu-west-1",
            "eu-west-2"
          ]
        }
      }
    }
  ]
}
```

Review and test SCPs carefully before attaching them broadly. Start with sandbox or development OUs before applying to production. Avoid breaking AWS Control Tower service-linked roles and baseline operations.

---

## Networking Standards

### CIDR Allocation Example

```text
Development:      10.10.0.0/16
Staging:          10.20.0.0/16
Production:       10.30.0.0/16
Shared Services:  10.40.0.0/16
Security:         10.50.0.0/16
Logging:          10.60.0.0/16
```

### VPC Subnet Pattern

```text
VPC /16
├── Public Subnets
│   ├── AZ-A /24
│   ├── AZ-B /24
│   └── AZ-C /24
├── Private App Subnets
│   ├── AZ-A /24
│   ├── AZ-B /24
│   └── AZ-C /24
└── Isolated Data Subnets
    ├── AZ-A /24
    ├── AZ-B /24
    └── AZ-C /24
```

### Network Rules

- Public subnets are for load balancers, NAT gateways, and approved edge services only.
- Application workloads should run in private subnets.
- Databases should run in isolated private subnets.
- Use VPC endpoints for AWS service access where practical.
- Centralize egress if required by compliance or security policy.
- Enable VPC Flow Logs for all workload VPCs.
- Production should not automatically trust development or staging networks.

---

## Validation Checklist

### Control Tower Validation

- [ ] Control Tower landing zone enabled or manual equivalent documented.
- [ ] Log Archive account exists.
- [ ] Audit/Security account exists.
- [ ] OUs are governed or governance status is documented.
- [ ] Account Factory or AFT process is documented.
- [ ] Enabled controls are listed.
- [ ] Drift status is reviewed.

### Organization Validation

- [ ] AWS Organization created.
- [ ] Required OUs created.
- [ ] Development, staging, production, security, logging, and shared services accounts exist.
- [ ] Accounts are moved into correct OUs.
- [ ] Delegated administrators are configured.

### IAM Validation

- [ ] Cross-account admin role works.
- [ ] Cross-account read-only role works.
- [ ] Security audit role works.
- [ ] Terraform execution role works.
- [ ] AFT execution roles work where AFT is used.
- [ ] MFA requirement is documented.
- [ ] Break-glass access is documented and restricted.

### Logging Validation

- [ ] CloudTrail organization trail or Control Tower baseline logging is enabled.
- [ ] Logs arrive in the logging/log archive account S3 bucket.
- [ ] Log bucket has versioning enabled.
- [ ] Log bucket encryption is enabled.
- [ ] Log file validation is enabled where applicable.
- [ ] Member accounts cannot disable centralized CloudTrail.

### Guardrail Validation

- [ ] Control Tower controls are enabled where required.
- [ ] Custom SCPs do not conflict with Control Tower service operations.
- [ ] CloudTrail tampering is denied.
- [ ] Leaving organization is denied.
- [ ] Unapproved Region deployment is denied or controlled.
- [ ] Public S3 bucket creation is denied or controlled.
- [ ] Root user restrictions are documented.

### Networking Validation

- [ ] CIDR ranges do not overlap.
- [ ] VPCs are deployed consistently.
- [ ] Private and public route tables are correct.
- [ ] VPC Flow Logs are enabled.
- [ ] Shared networking connectivity is tested.

### Terraform Validation

- [ ] `terraform fmt` passes.
- [ ] `terraform validate` passes.
- [ ] Linting passes.
- [ ] Security scan passes or exceptions are documented.
- [ ] Remote state and locking work.
- [ ] Production apply requires approval.
- [ ] Terraform does not unintentionally manage Control Tower-owned resources.

---

## Definition of Done

The project is complete when:

- The AWS Control Tower strategy is documented.
- The AWS Organization is created and structured.
- Required accounts are created, enrolled, or documented.
- Centralized logging is active and protected.
- Control Tower controls and custom guardrails are deployed and tested.
- Cross-account roles are working.
- Networking standards are implemented using Terraform modules.
- Security services are enabled and aggregated centrally.
- CI/CD workflow validates Terraform changes.
- Validation evidence is complete.
- The project can be explained clearly in a technical interview.

---

## Interview Summary

Use this summary when explaining the project:

> I implemented a multi-account AWS landing zone to create a secure and repeatable cloud foundation. The preferred enterprise model used AWS Control Tower to establish the landing zone baseline, including AWS Organizations, governed OUs, log archive and audit/security accounts, identity integration, and preventive/detective/proactive controls. I then extended the foundation with Terraform modules for custom IAM roles, account baselines, SCP guardrails, centralized logging validation, VPC standards, shared services networking, and CI/CD validation. For environments where Control Tower was not available, I implemented the equivalent governance model manually using AWS Organizations, CloudTrail, SCPs, IAM roles, and Terraform. The key outcome was a governed AWS operating model with account isolation, centralized auditability, least-privilege access, controlled networking, and repeatable infrastructure delivery.

---

## Key Engineering Principles

- Prefer AWS Control Tower for enterprise landing zone acceleration.
- Use Terraform to extend the landing zone, not fight the landing zone.
- Separate workloads by account.
- Keep the management account clean.
- Centralize security and logging.
- Use least-privilege access.
- Use guardrails, not manual policy reminders.
- Make infrastructure repeatable with Terraform.
- Validate every control with evidence.
- Treat production as protected and change-controlled.
- Document assumptions, trade-offs, exceptions, and ownership boundaries.
