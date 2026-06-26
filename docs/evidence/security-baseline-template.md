# Security baseline evidence template

## Change metadata

- Date:
- Operator:
- Change/request ID:
- Terraform commit:
- Deployment scope:
- Account ID:
- Region:
- Cost approval reference:

## Control Tower ownership check

- Control Tower landing zone status:
- Config recorder/delivery ownership:
- Existing security delegated administrators:
- Existing aggregators:

## Terraform plan evidence

- Plan file/artifact location:
- Scope:
- Region:
- Create/update/delete summary:
- Paid services enabled:
- Reviewer:
- Approval:

## Service validation

| Service | Command evidence file | Expected result | Actual result | Owner |
|---|---|---|---|---|
| GuardDuty | `guardduty-*.json` | Detector active and org config expected |  |  |
| Security Hub | `securityhub-*.json` | Hub enabled and aggregation expected |  |  |
| IAM Access Analyzer | `access-analyzer-*.json` | Organization analyzer active |  |  |
| AWS Config | `config-*.json` | Aggregator present only if approved |  |  |
| S3 BPA | `s3-account-public-access-block-*.json` | All four BPA flags true |  |  |
| Inspector | `inspector-*.json` | Enabled only if approved |  |  |
| Macie | `macie-*.json` | Enabled only if approved |  |  |

## Alert routing

- Alert target ARN:
- Test event ID:
- Ticket/page generated:
- Owner acknowledged:
- SLA:

## Exceptions and follow-up

- Exceptions:
- Failed checks:
- Remediation owner:
- Due date:
