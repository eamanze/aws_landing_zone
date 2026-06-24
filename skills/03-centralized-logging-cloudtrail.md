# Skill 03 — Centralized Logging and AWS CloudTrail

## Skill Purpose
Centralize audit logs across all AWS accounts using an organization CloudTrail trail, a dedicated logging account, encrypted S3 buckets, and restricted access policies.

## What You Must Know

- CloudTrail management events
- CloudTrail data events
- Organization trails
- Log archive account pattern
- S3 bucket policies for CloudTrail delivery
- KMS encryption for logs
- S3 versioning and lifecycle policies
- Log file validation
- VPC Flow Logs
- AWS Config log delivery

## Target Logging Architecture

```text
All AWS Accounts
      |
      |  CloudTrail organization trail
      v
Logging Account
      |
      |-- S3 central log bucket
      |-- KMS key for log encryption
      |-- Lifecycle and retention policy
      |-- Restricted auditor/security access
```

## Implementation Tasks

1. Create log archive S3 bucket in the logging account.
2. Enable bucket versioning.
3. Enable default encryption with KMS.
4. Create bucket policy allowing CloudTrail delivery.
5. Create KMS key policy allowing CloudTrail encryption.
6. Create CloudTrail organization trail from the management account.
7. Enable log file validation.
8. Configure lifecycle retention.
9. Configure VPC Flow Logs to central destination.
10. Validate that events from all accounts arrive in the bucket.

## Terraform Resources to Learn

- `aws_cloudtrail`
- `aws_s3_bucket`
- `aws_s3_bucket_policy`
- `aws_s3_bucket_versioning`
- `aws_s3_bucket_server_side_encryption_configuration`
- `aws_s3_bucket_lifecycle_configuration`
- `aws_kms_key`
- `aws_kms_alias`
- `aws_flow_log`
- `aws_cloudwatch_log_group`

## Required Controls

- CloudTrail organization trail enabled.
- Log file validation enabled.
- Centralized S3 bucket encryption enabled.
- Bucket versioning enabled.
- Bucket public access blocked.
- SCP prevents CloudTrail tampering.
- SCP prevents deletion of log archive bucket.
- Access to log archive account is restricted.

## Validation Checks

```bash
aws cloudtrail describe-trails --include-shadow-trails
aws cloudtrail get-trail-status --name <trail-name>
aws s3 ls s3://<central-log-bucket>/AWSLogs/ --recursive | head
```

## Common Mistakes

- Creating separate account-level trails instead of an organization trail.
- Storing logs in the same account as workloads only.
- Forgetting KMS key policy permissions for CloudTrail.
- Allowing administrators in workload accounts to delete or modify audit logs.
- Not enabling log file validation.
- Not testing log delivery from each account.

## Interview Talking Point

> I configured centralized audit logging using a CloudTrail organization trail. Logs from all member accounts were delivered to a dedicated logging account, encrypted with KMS, protected with S3 policies, and retained according to compliance requirements. This made audit evidence independent of workload accounts.
