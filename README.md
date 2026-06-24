# Multi-Account AWS Landing Zone — AGENTS and Skills Pack

This pack contains a production-grade `AGENTS.md` file and a structured `skills/` folder for building a multi-account AWS landing zone.

The updated version now includes **AWS Control Tower** as the preferred enterprise landing zone approach, with Terraform used to extend and customize the baseline.

## Project Scenario

Implement a multi-account AWS landing zone using separate accounts for development, staging, production, security, logging, and shared services.

Use:

- AWS Control Tower
- AWS Organizations
- Account Factory
- Account Factory for Terraform, where appropriate
- IAM Identity Center or federated access
- IAM cross-account roles
- Centralized CloudTrail and log archive
- Control Tower controls
- Custom SCP guardrails where required
- Networking standards
- Terraform modules
- CI/CD validation
- Audit evidence

## Included Files

```text
AGENTS.md
skills/
├── README.md
├── 01-aws-organizations-and-account-strategy.md
├── 02-iam-cross-account-access.md
├── 03-centralized-logging-cloudtrail.md
├── 04-guardrails-and-scp.md
├── 05-networking-standards.md
├── 06-terraform-modules-and-state.md
├── 07-security-baseline.md
├── 08-cicd-and-change-management.md
├── 09-validation-and-audit-evidence.md
├── 10-interview-explanation.md
└── 11-aws-control-tower-landing-zone.md
```

## Recommended Implementation Model

```text
AWS Control Tower creates and governs the landing zone baseline.
AWS Organizations provides the multi-account structure.
Account Factory or AFT provisions accounts.
Control Tower controls provide preventive, detective, and proactive governance.
Terraform extends the landing zone with custom networking, IAM, security, logging validation, CI/CD, and workload baselines.
```

## Recommended Next Step

Copy `AGENTS.md` and the `skills/` folder into the root of your GitHub repository.

Start with:

1. `skills/11-aws-control-tower-landing-zone.md`
2. `skills/01-aws-organizations-and-account-strategy.md`
3. `skills/06-terraform-modules-and-state.md`

Then proceed through the remaining skill files as execution guides.
