# Skill 06 — Terraform Modules and Remote State

## Skill Purpose
Build a repeatable, production-grade Terraform structure for managing a multi-account AWS landing zone.

## What You Must Know

- Terraform providers and aliases
- Terraform modules
- Remote state using S3
- State locking using DynamoDB
- Workspace vs directory-based environment separation
- Input variables and outputs
- Data sources
- Terraform plan/apply workflow
- Importing existing resources
- Drift detection
- Secure secret handling

## Recommended Terraform Layout

```text
infra/
├── modules/
│   ├── organizations/
│   ├── organizational-units/
│   ├── account-baseline/
│   ├── iam-cross-account-roles/
│   ├── scp-guardrails/
│   ├── cloudtrail-organization/
│   ├── log-archive-bucket/
│   ├── security-baseline/
│   ├── vpc-standard/
│   ├── transit-gateway/
│   └── terraform-state-backend/
└── environments/
    ├── organization/
    ├── security/
    ├── logging/
    ├── shared-services/
    ├── development/
    ├── staging/
    └── production/
```

## Remote State Pattern

Each account or environment should have a separate state file.

```hcl
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "production/network/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

## Provider Alias Pattern

```hcl
provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "production"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::<PRODUCTION_ACCOUNT_ID>:role/TerraformExecutionRole"
  }
}
```

## Required Terraform Standards

- Use modules for repeatability.
- Keep organization-level resources separate from account-level resources.
- Keep production state separate from non-production state.
- Use explicit provider aliases for cross-account resources.
- Do not store secrets in `.tfvars`.
- Commit `.terraform.lock.hcl`.
- Do not commit `.terraform/`, `.tfstate`, or crash logs.
- Run fmt, validate, lint, and security scans.

## CI Validation Commands

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
tflint
checkov -d .
```

## Implementation Tasks

1. Create remote backend module.
2. Create organization module.
3. Create OU module.
4. Create account baseline module.
5. Create IAM role module.
6. Create SCP module.
7. Create centralized CloudTrail module.
8. Create standard VPC module.
9. Create environment-specific configurations.
10. Add CI/CD validation.

## Common Mistakes

- Using one state file for everything.
- Running production apply from a laptop.
- Hardcoding account IDs across modules.
- Not pinning provider versions.
- Not using state locking.
- Not reviewing Terraform plans before apply.
- Not documenting manual imports.

## Interview Talking Point

> I designed Terraform modules for the organization, accounts, IAM roles, guardrails, logging, and networking. Each account and environment had separate state, stored remotely in S3 with DynamoDB locking. This made the landing zone repeatable, reviewable, and safer to operate.


---

## AWS Control Tower and Terraform Ownership Update

When AWS Control Tower is used, Terraform must be carefully scoped so it extends the landing zone instead of accidentally taking ownership of Control Tower-managed resources.

Terraform should manage:

- Custom IAM roles
- Custom SCPs not covered by Control Tower controls
- VPC and networking modules
- Transit Gateway and shared services
- Security service configuration
- Workload baselines
- CI/CD validation resources
- Evidence automation

Terraform should not blindly manage:

- Control Tower landing zone baseline resources
- Mandatory Control Tower resources
- Control Tower service-linked roles
- Control Tower-managed CloudFormation StackSets
- Baseline resources created by Control Tower unless ownership is documented

Where account provisioning must be GitOps-driven, use AWS Control Tower Account Factory for Terraform.

Interview talking point:

> I used Terraform for extension and customization, but I did not fight Control Tower ownership. For account vending, I would use AFT where the business needs Terraform-based account requests and customization pipelines.

