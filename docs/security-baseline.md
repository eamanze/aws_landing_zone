# Security baseline design

## Status

Plan-only. Do not enable paid security services or delegated administrators
until cost and Terraform plans are approved.

## Ownership model

The security account is the delegated administrator and findings aggregation
account. The management account is used only for organization-level delegation
operations that AWS requires to originate from the management account.

Plans are generated separately:

```text
management account / Region -> delegated administrator designation
security account / Region   -> service enablement, org settings, aggregation, alerts
member account / Region     -> account-level public access block or optional member services
```

This avoids circular provider dependencies and makes the blast radius of each
plan reviewable.

## Control Tower boundary

Control Tower can own AWS Config recorders, delivery channels, managed rules,
aggregation, and baseline StackSets. Terraform must check ownership before
creating any Config resource. The module defaults
`control_tower_manages_config = true`, which blocks Config aggregator creation
until a non-overlapping design is approved.

## Services

| Service | Pattern | Default |
|---|---|---|
| GuardDuty | Management account designates security account; security account enables detector and organization auto-enrollment per Region | Disabled |
| Security Hub | Management account designates security account; security account enables Security Hub and finding aggregation | Disabled |
| IAM Access Analyzer | Management account registers security account as delegated administrator; security account creates organization analyzer per approved Region | Disabled |
| AWS Config aggregation | Read-only organization aggregator only when not already Control Tower-managed | Disabled |
| S3 account BPA | Account-level Block Public Access in target account | Disabled |
| Inspector | Optional delegated admin and enabler | Disabled |
| Macie | Optional delegated admin and session/org config | Disabled |
| Alerts | EventBridge routes security findings to an approved target ARN | Disabled |

## Alert routing and severity ownership

| Finding source | Initial routing | Owner | Severity handling |
|---|---|---|---|
| GuardDuty | EventBridge to `<ALERT_TARGET:security_operations>` | `<OWNER:secops_threat_detection>` | High/Critical: immediate triage; Medium: next business day |
| Security Hub | EventBridge to `<ALERT_TARGET:security_operations>` | `<OWNER:secops_posture>` | Critical/High failed controls require ticket and owner |
| IAM Access Analyzer | EventBridge to `<ALERT_TARGET:security_operations>` | `<OWNER:iam_security>` | External access findings triaged as High until classified |
| Inspector | EventBridge to `<ALERT_TARGET:security_operations>` | `<OWNER:vulnerability_management>` | Critical/High according to vulnerability SLA |
| Macie | EventBridge to `<ALERT_TARGET:security_operations>` | `<OWNER:data_security>` | Sensitive-data findings triaged by data classification |

The Terraform module creates routing infrastructure only when
`enable_alert_routing=true` and `alert_target_arn` is supplied. Downstream
filtering, ticket creation, paging, and deduplication are owned by the alerting
platform.

## Recurring cost expectations

- GuardDuty: charged by analyzed data sources and enabled protection plans.
- Security Hub: charged by security checks and finding ingestion/automation.
- Inspector: charged by scanned workloads and package/image/function coverage.
- Macie: charged by S3 inventory/classification volume and jobs.
- AWS Config: source account recording and rule evaluations are billable;
  aggregators themselves have no additional charge.
- EventBridge/SNS/SIEM: event routing, notifications, and downstream ingestion
  can add cost.
- S3 account-level Block Public Access has no direct service charge.

## Validation commands

```bash
./scripts/validate-security-baseline.sh --mode guardduty --region <REGION> --output-dir docs/evidence/security
./scripts/validate-security-baseline.sh --mode securityhub --region <REGION> --output-dir docs/evidence/security
./scripts/validate-security-baseline.sh --mode access-analyzer --region <REGION> --output-dir docs/evidence/security
./scripts/validate-security-baseline.sh --mode config --region <REGION> --output-dir docs/evidence/security
./scripts/validate-security-baseline.sh --mode s3-bpa --region <REGION> --account-id <ACCOUNT_ID> --output-dir docs/evidence/security
./scripts/validate-security-baseline.sh --mode inspector --region <REGION> --output-dir docs/evidence/security
./scripts/validate-security-baseline.sh --mode macie --region <REGION> --output-dir docs/evidence/security
```

## Approval checklist

- [ ] Approved Regions are explicitly listed.
- [ ] Cost owner approved GuardDuty, Security Hub, Config, Inspector, and Macie
      service charges.
- [ ] Control Tower Config ownership is documented.
- [ ] Management-account delegation plan reviewed separately.
- [ ] Security-account regional plans reviewed separately.
- [ ] Member-account plans reviewed separately.
- [ ] Alert target ARN, severity owner, and response SLA are approved.
- [ ] Evidence directory and retention are approved.

## Sources

- GuardDuty Organizations:
  https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_organizations.html
- Security Hub Organizations:
  https://docs.aws.amazon.com/securityhub/latest/userguide/designate-orgs-admin-account.html
- IAM Access Analyzer:
  https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-getting-started.html
- AWS Config aggregation:
  https://docs.aws.amazon.com/config/latest/developerguide/aggregate-data.html
