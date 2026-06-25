# log-archive-bucket

Terraform-owned log archive or logging-extension bucket module.

This module must not manage an AWS Control Tower-owned Log Archive bucket. The
default inputs are intentionally safe:

- `create_bucket = false`
- `control_tower_owned_bucket = true`
- no bucket policy attachment to an existing bucket

Use this only for:

1. manual Organizations mode, where Terraform owns the log archive bucket; or
2. an explicitly approved non-Control-Tower logging extension bucket, for
   example a VPC Flow Logs archive bucket that Control Tower does not own.

## What it creates when explicitly enabled

- S3 bucket
- S3 Block Public Access
- S3 versioning
- SSE-KMS default encryption
- TLS-only bucket-policy deny
- least-privilege CloudTrail delivery statements for exact trail ARNs
- least-privilege VPC Flow Logs delivery statements for exact accounts/Regions
- optional Terraform-owned KMS key and alias
- lifecycle transitions and noncurrent-version retention
- optional Object Lock at bucket creation only, with explicit acknowledgement

## What it does not do

- It does not import or mutate Control Tower buckets.
- It does not create an organization trail.
- It does not create AWS Config recorders, delivery channels, aggregators, KMS
  keys, or StackSets owned by Control Tower.
- It does not enable Object Lock unless the separate approval acknowledgement is
  supplied.

## Deployment account

Deploy from the log archive account, or from a platform role assuming into the
log archive account, only after the ownership boundary is approved.

## Sources

- CloudTrail S3 bucket policies:
  https://docs.aws.amazon.com/awscloudtrail/latest/userguide/create-s3-bucket-policy-for-cloudtrail.html
- CloudTrail KMS key policies:
  https://docs.aws.amazon.com/awscloudtrail/latest/userguide/create-kms-key-policy-for-cloudtrail.html
- VPC Flow Logs S3 bucket policies:
  https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-s3-permissions.html
