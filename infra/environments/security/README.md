# security environment

Terraform root for approved security-account and management-account security
baseline plans.

This root is intentionally planned one account and one Region at a time. Use the
appropriate AWS profile or role for the selected `deployment_scope`; do not build
a circular cross-account provider graph here.

## Plan modes

- `management-delegation`: run from the management account to designate
  delegated administrators.
- `security-regional`: run from the security account to enable regional
  administrator services and aggregation.
- `member-account`: run from one member account to apply account-level S3 Block
  Public Access and optional per-account services.

## Default safety

All enablement variables default to `false`. Paid services require:

```hcl
cost_approval = "I approve the recurring security baseline cost and reviewed Terraform plan"
```

Do not set this until the cost and plan are approved.

## Example plan-only workflow

```bash
terraform -chdir=infra/environments/security init \
  -backend-config=backend.security.hcl

terraform -chdir=infra/environments/security validate

terraform -chdir=infra/environments/security plan \
  -var-file=security.auto.tfvars
```

Generate separate plans for each account/Region combination. Do not apply until
the explicit approval gate is complete.
