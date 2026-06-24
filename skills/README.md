# Skills Folder — Multi-Account AWS Landing Zone

This folder contains the skill guides needed to design, implement, validate, document, and explain a production-grade multi-account AWS landing zone.

The updated version includes **AWS Control Tower** as the preferred enterprise landing zone accelerator, while still supporting a manual AWS Organizations + Terraform implementation for lab or portfolio environments.

## Skills Included

1. AWS Organizations and Account Strategy
2. IAM and Cross-Account Access
3. Centralized Logging and AWS CloudTrail
4. Guardrails and Service Control Policies
5. Networking Standards
6. Terraform Modules and Remote State
7. Security Baseline
8. CI/CD and Change Management
9. Validation and Audit Evidence
10. Interview Explanation
11. AWS Control Tower Landing Zone

## Recommended Learning and Build Order

Use the Control Tower skill early because it affects account provisioning, logging, guardrails, identity, and Terraform ownership boundaries.

```text
AWS Control Tower landing zone
→ Account and OU strategy
→ IAM and cross-account access
→ Central logging
→ Control Tower controls and custom SCP guardrails
→ Networking standards
→ Terraform modules and remote state
→ Security baseline
→ CI/CD workflow
→ Validation evidence
→ Interview explanation
```

## How to Use These Skills

Use each skill file as a project execution guide. Each skill includes:

- What to learn
- What to implement
- Terraform resources or AWS services to understand
- Validation checks
- Common mistakes
- Interview talking point

## Important Implementation Principle

For a production enterprise project, prefer this approach:

```text
AWS Control Tower establishes the governed landing zone baseline.
Terraform extends the landing zone with custom infrastructure.
AFT is used when account provisioning and customization need GitOps/Terraform workflow.
```

For a portfolio or lab project where AWS Control Tower is not available, document the manual equivalent:

```text
AWS Organizations + Terraform + SCPs + CloudTrail + IAM roles + centralized logging.
```
