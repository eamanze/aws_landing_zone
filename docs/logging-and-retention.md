# Logging and retention design

## Status

Design and plan only. This document does not authorize creation, import,
deletion, or modification of AWS Control Tower logging resources.

## Ownership boundary

AWS Control Tower is the owner of the landing-zone centralized logging baseline
when the Control Tower-first mode is selected. Terraform must not duplicate or
import the Control Tower organization trail, AWS Config recorder or delivery
channel, Log Archive buckets, KMS keys, service-linked roles, or managed
StackSets.

Terraform may manage only approved extensions:

- Terraform-owned log archive bucket in manual Organizations mode.
- Terraform-owned non-Control-Tower extension bucket, such as a dedicated VPC
  Flow Logs archive bucket, after approval.
- Manual-mode organization trail only when Control Tower is not the landing-zone
  owner.
- VPC Flow Log resources in workload/network modules that deliver into an
  approved central destination.

## Control Tower centralized logging inspection

Before any Terraform logging change, inspect the existing Control Tower baseline
with read-only commands:

```bash
./scripts/validate-cloudtrail.sh \
  --mode control-tower-inventory \
  --region <REGION:home> \
  --output-dir docs/evidence/logging

./scripts/validate-cloudtrail.sh \
  --mode trail-status \
  --region <REGION:home> \
  --trail-name <TRAIL_NAME_OR_ARN:control_tower_trail> \
  --output-dir docs/evidence/logging

./scripts/validate-cloudtrail.sh \
  --mode bucket-controls \
  --bucket <S3_BUCKET:control_tower_log_archive> \
  --output-dir docs/evidence/logging
```

Expected evidence:

- landing-zone version and drift status;
- organization trail exists and is logging;
- trail is an organization trail;
- log file validation status is recorded;
- destination bucket, prefix, and KMS key are recorded;
- log archive bucket has versioning, encryption, public access block, and a
  non-public policy status.

## Central delivery pattern

Control Tower-first:

```text
Governed accounts and governed Regions
  -> Control Tower-managed organization CloudTrail and Config baseline
  -> Log Archive account
  -> Control Tower-owned S3/KMS resources
```

Terraform extension:

```text
Workload/shared VPC Flow Logs
  -> approved central S3 destination in Log Archive or logging extension account
  -> bucket/KMS policies allowing delivery.logs.amazonaws.com with exact
     SourceAccount and SourceArn conditions
```

Manual mode only:

```text
AWS Organizations management account
  -> Terraform-owned organization CloudTrail
  -> Terraform-owned log archive bucket
  -> Terraform-owned customer-managed KMS key or approved existing key
```

## Encryption, versioning, TLS, and public access

For Terraform-owned buckets, `infra/modules/log-archive-bucket` enforces:

- S3 Block Public Access;
- versioning;
- SSE-KMS default encryption;
- TLS-only access through a bucket-policy explicit deny;
- least-privilege CloudTrail delivery for exact trail ARNs;
- least-privilege VPC Flow Logs delivery for exact source accounts and Regions;
- optional log-reader role access by exact role ARN only.

For Control Tower-owned buckets, validate these controls but do not attach a
Terraform bucket policy or KMS policy.

## Log file validation

Manual-mode organization trails must keep CloudTrail log file validation
enabled. In Control Tower-first mode, record the Control Tower trail setting and
validate log/digest delivery. CloudTrail log file validation creates digest
files that can be validated with the AWS CLI.

Example read-only validation:

```bash
./scripts/validate-cloudtrail.sh \
  --mode validate-log-files \
  --region <REGION:home> \
  --trail-name <TRAIL_ARN:control_tower_or_manual> \
  --start-time <ISO8601:start> \
  --end-time <ISO8601:end> \
  --output-dir docs/evidence/logging
```

## Retention and lifecycle

Required decisions before deployment:

- `<RETENTION_DAYS:cloudtrail_management_events>` REQUIRED
- `<RETENTION_DAYS:vpc_flow_logs>` REQUIRED
- `<STORAGE_CLASS_TRANSITION_DAYS:ia>` default proposal: 90 days
- `<STORAGE_CLASS_TRANSITION_DAYS:glacier>` default proposal: 365 days
- `<EXPIRATION_DAYS:logs>` REQUIRED; default proposal is no expiration until a
  compliance retention period is approved

Terraform-owned buckets preserve recoverability by retaining noncurrent object
versions for at least 90 days. The default module value is 365 days.

## Object Lock

Object Lock is optional and requires a separate design decision. It must be
approved before bucket creation because Object Lock is a bucket-level creation
choice in this module and has operational/legal retention consequences.

Approval text required by the module:

```text
I approve Object Lock for this Terraform-owned log archive bucket
```

## VPC Flow Log destination pattern

Use S3 delivery for centralized long-term retention unless the workload needs a
CloudWatch Logs or Firehose near-real-time processing path. The S3 bucket policy
must allow the `delivery.logs.amazonaws.com` service principal, condition writes
on `aws:SourceAccount`, require `s3:x-amz-acl =
bucket-owner-full-control`, and scope `aws:SourceArn` to the source account and
Region.

Do not let automatic VPC Flow Logs bucket-policy attachment overwrite a central
bucket policy. The bucket owner should manage the policy centrally.

## Queries validating logs from every governed account

Presence check for every governed account:

```bash
./scripts/validate-cloudtrail.sh \
  --mode governed-account-logs \
  --bucket <S3_BUCKET:central_logs> \
  --prefix <S3_PREFIX:cloudtrail> \
  --account-id <ACCOUNT_ID:management> \
  --account-id <ACCOUNT_ID:security> \
  --account-id <ACCOUNT_ID:log_archive> \
  --account-id <ACCOUNT_ID:shared_services> \
  --account-id <ACCOUNT_ID:development> \
  --account-id <ACCOUNT_ID:staging> \
  --account-id <ACCOUNT_ID:production> \
  --output-dir docs/evidence/logging
```

Athena-style validation query, if an external table is approved later:

```sql
SELECT recipientaccountid, count(*) AS events
FROM <ATHENA_DATABASE:logs>.<ATHENA_TABLE:cloudtrail>
WHERE eventtime >= current_timestamp - interval '1' day
GROUP BY recipientaccountid
ORDER BY recipientaccountid;
```

The expected result is one row for each governed account, unless the account was
created too recently for CloudTrail delivery latency.

## Approval gates

- Gate L1: Control Tower logging inventory complete and evidence stored.
- Gate L2: ownership boundary approved; no Control Tower resource import.
- Gate L3: retention, KMS administration, log-reader roles, and cost approved.
- Gate L4: VPC Flow Logs central destination approved.
- Gate L5: Terraform plan reviewed.
- Gate L6: apply approved for non-production first.

## Sources

- AWS Control Tower mandatory controls and Landing Zone 4.0 centralized logging
  changes: https://docs.aws.amazon.com/controltower/latest/controlreference/mandatory-controls.html
- AWS Control Tower Control Catalog:
  https://docs.aws.amazon.com/controltower/latest/controlreference/controls-reference.html
- CloudTrail log file validation:
  https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-log-file-validation-intro.html
- CloudTrail KMS key policies:
  https://docs.aws.amazon.com/awscloudtrail/latest/userguide/create-kms-key-policy-for-cloudtrail.html
- CloudTrail S3 bucket policies:
  https://docs.aws.amazon.com/awscloudtrail/latest/userguide/create-s3-bucket-policy-for-cloudtrail.html
- VPC Flow Logs S3 delivery permissions:
  https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-s3-permissions.html
