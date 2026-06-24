# Terraform State Backend Bootstrap

## Purpose

This is the only Terraform root initially permitted to use local state. It creates the S3/KMS backend used by all later roots and must be migrated to that backend immediately after an approved apply.

## Before planning

- Resolve `<ACCOUNT_ID:terraform_state>`, `<REGION:terraform_state>`, named IAM administrator/execution role ARNs, owner, and cost center.
- Verify the selected account/Region and the IAM principals already exist.
- Copy `terraform.tfvars.example` to ignored `terraform.tfvars`, replace every typed placeholder, and set `acknowledge_local_state_risk = true` only after reading [MIGRATION.md](MIGRATION.md).
- Authenticate with temporary credentials authorized to create the bucket, KMS key/alias, and policies.
- Confirm the expected account through `aws sts get-caller-identity` before planning.

## Plan warning

The plan and local state contain account IDs, principal ARNs, bucket/KMS policy data, and generated resource identifiers. Save plans outside the repository, restrict their access, and delete them after the approved change. A plan does not authorize apply.

The provider uses `allowed_account_ids` to refuse the wrong AWS account. The bucket name is derived from the configured prefix, actual caller account ID, and provider Region.

## Destroy warning

The module uses `prevent_destroy = true` on the S3 bucket and KMS key and `force_destroy = false`. A normal destroy must fail rather than delete the state authority for every environment. Do not weaken these protections without a separate migration, backup, evidence, and recovery approval.

## Locking

Consumers use S3 native lockfiles with `use_lockfile = true`. No DynamoDB lock table is created because DynamoDB state locking is deprecated for this Terraform version.

## Migration

After the approved apply, follow [MIGRATION.md](MIGRATION.md). Backend values are exposed by outputs, but backend blocks cannot consume those outputs automatically.
