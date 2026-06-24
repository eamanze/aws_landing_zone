# Skill 08 — CI/CD and Change Management for Infrastructure

## Skill Purpose
Deploy landing zone infrastructure safely using automated checks, pull requests, Terraform plans, approvals, and controlled production changes.

## What You Must Know

- Git branching strategy
- Pull request reviews
- Terraform fmt and validate
- TFLint
- Checkov or tfsec
- Terraform plan artifacts
- Manual approvals
- Environment promotion
- Drift detection
- Change records and rollback planning

## Recommended Pipeline Flow

```text
Pull Request Opened
        |
        v
Terraform fmt check
        |
        v
Terraform validate
        |
        v
TFLint
        |
        v
Checkov / tfsec
        |
        v
Terraform plan
        |
        v
Peer review
        |
        v
Merge
        |
        v
Apply to development
        |
        v
Promote to staging
        |
        v
Manual approval
        |
        v
Apply to production
        |
        v
Post-deployment validation
```

## Branch Strategy

| Branch | Purpose |
|---|---|
| feature/* | Individual infrastructure changes |
| develop | Integration branch for development environment |
| staging | Pre-production validation |
| main | Production-approved infrastructure |

## Required Controls

- Pull request required for all changes.
- At least one reviewer for non-production.
- Additional approval for production.
- Terraform plan reviewed before apply.
- Production apply must not run automatically from unreviewed changes.
- Pipeline role must use least privilege.
- Plan and apply logs must be retained.

## Example GitHub Actions Stages

```yaml
name: terraform-validation

on:
  pull_request:
    paths:
      - 'infra/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - run: terraform fmt -check -recursive infra
      - run: terraform -chdir=infra/environments/development init -backend=false
      - run: terraform -chdir=infra/environments/development validate
```

## Implementation Tasks

1. Define branching strategy.
2. Add Terraform validation pipeline.
3. Add linting.
4. Add security scanning.
5. Add Terraform plan generation.
6. Save plan output as artifact.
7. Add manual approval before production.
8. Add post-deployment validation scripts.
9. Document rollback process.

## Common Mistakes

- Applying Terraform manually in production.
- Running pipeline with overly broad admin permissions.
- Not saving plan output.
- Not separating plan and apply.
- Ignoring drift.
- Skipping approvals for production.

## Interview Talking Point

> I treated infrastructure changes like application changes. Every Terraform update went through pull request review, formatting, validation, linting, security scanning, plan review, and approval before production apply. This reduced risk and gave us an audit trail for platform changes.


---

## AFT and Control Tower Pipeline Update

When AWS Control Tower Account Factory for Terraform is used, account provisioning becomes part of the infrastructure delivery workflow.

The CI/CD model should distinguish between:

1. Landing zone governance changes
2. AFT account requests
3. Global account customizations
4. Account-specific customizations
5. Workload infrastructure deployment

Recommended flow:

```text
Pull request
→ Validate account request or Terraform module
→ Security/platform review
→ Merge to approved branch
→ AFT pipeline or Terraform pipeline runs
→ Account provisioned/customized
→ Validation evidence collected
```

Production governance changes and account vending changes should require formal review because they affect the organization-level control plane.

Interview talking point:

> I separated account-vending workflow from workload deployment workflow so that new AWS accounts, baseline controls, and production infrastructure changes all had the right level of review and auditability.

