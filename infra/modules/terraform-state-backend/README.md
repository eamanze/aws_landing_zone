# Terraform State Backend Module

Creates the protected S3 backend used by all later Terraform roots.

## Security and recovery controls

- Globally unique bucket name: `<prefix>-<caller-account-id>-<provider-region>`.
- S3 Block Public Access and bucket-owner-enforced object ownership.
- Versioning and customer-managed KMS encryption with rotation and S3 Bucket Keys.
- TLS-only bucket policy and denial of uploads without an explicit `aws:kms` header.
- Explicit bucket/KMS administrators and prefix-scoped state principals; no wildcard access principals.
- State principals can read/write state and delete only `*.tflock` lock objects.
- Noncurrent versions transition to Standard-IA after 30 days, Glacier Flexible Retrieval after 90 days, and expire after 365 days by default. Current state is never expired.
- Incomplete multipart uploads are removed after seven days.
- `force_destroy = false` plus `prevent_destroy = true` on the bucket and KMS key.

## Locking decision

Use S3 native lockfiles with backend setting `use_lockfile = true`. Terraform `1.11.1` supports this mode, and current HashiCorp documentation marks DynamoDB-based locking deprecated. This module therefore creates no DynamoDB table.

Reference: [HashiCorp S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3#state-locking).

## Usage example

```hcl
module "terraform_state_backend" {
  source = "../../modules/terraform-state-backend"

  bucket_name_prefix = "company-landing-zone-tfstate"

  bucket_administrator_arns = var.bucket_administrator_arns
  kms_administrator_arns    = var.kms_administrator_arns
  state_access_principals   = var.state_access_principals

  owner       = var.owner
  cost_center = var.cost_center
}
```

Example access input:

```hcl
state_access_principals = {
  platform_ci = {
    principal_arn = "<IAM_ROLE_ARN:terraform_execution>"
    state_key_prefixes = [
      "bootstrap",
      "organization",
      "security",
      "logging",
      "shared-services",
      "development",
      "staging",
      "production",
    ]
  }
}
```

Replace typed placeholders through a non-committed `terraform.tfvars`. The IAM roles/users must already exist; KMS rejects invalid principals. Do not pass STS assumed-role session ARNs.

## Backend consumer configuration

After bootstrap and migration, each environment declares an S3 backend and supplies these values through a non-committed backend configuration file:

```hcl
bucket       = "<OUTPUT:bucket_name>"
key          = "development/terraform.tfstate"
region       = "<OUTPUT:bucket_region>"
encrypt      = true
kms_key_id   = "<OUTPUT:kms_key_arn>"
use_lockfile = true
expected_bucket_owner = "<OUTPUT:bucket_account_id>"
allowed_account_ids   = ["<OUTPUT:bucket_account_id>"]
```

Backend blocks cannot consume Terraform outputs directly. Record the output values in the approved CI configuration or parameter system and attach the matching `state_access_policy_json` policy to each execution principal.

## Destroy warning

`terraform destroy` is intentionally blocked for the bucket and KMS key. Deleting either can make every environment unmanaged or unrecoverable. Removal requires a separately reviewed code change that disables `prevent_destroy`, proves all states have been migrated and backed up, empties all object versions safely, and addresses the KMS deletion window.

Never use `-target`, manual bucket emptying, KMS key scheduling, or state removal to bypass this protection.

## Inputs and outputs

See `variables.tf` for validated inputs. Outputs provide bucket name/ARN/Region/account, KMS key ARN/alias, backend configuration values, and prefix-scoped identity policy JSON for consumer roles.
