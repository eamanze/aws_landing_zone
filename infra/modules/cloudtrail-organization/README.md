# cloudtrail-organization

Manual-mode organization trail module.

This module is intentionally disabled by default and must not be used in a
Control Tower-first deployment. Control Tower owns its organization
CloudTrail/centralized logging baseline, related StackSets, Config integration,
Log Archive resources, and lifecycle updates.

## Safe defaults

- `manual_mode_enabled = false`
- `control_tower_enabled = true`
- no CloudTrail resource is planned

## When this module is allowed

Use it only if the project is explicitly switched to manual AWS Organizations
mode or an approved exception states that Control Tower does not own centralized
logging.

In manual mode it creates one Terraform-owned organization trail with:

- `is_organization_trail = true`
- multi-Region logging by default
- global service events by default
- log file validation enabled by default and required
- SSE-KMS via an approved customer-managed key
- optional S3 data events only when explicitly enabled

## Required companion resources

This module expects a destination bucket and KMS key to exist and be owned by
Terraform/manual mode. Pair it with `infra/modules/log-archive-bucket` only when
that bucket is not Control Tower-owned.

## Sources

- Organization trails:
  https://docs.aws.amazon.com/awscloudtrail/latest/userguide/creating-an-organizational-trail.html
- Log file validation:
  https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-log-file-validation-intro.html
- CloudTrail KMS policy requirements:
  https://docs.aws.amazon.com/awscloudtrail/latest/userguide/create-kms-key-policy-for-cloudtrail.html
