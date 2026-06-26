# security-baseline

Delegated security-administrator baseline for Control Tower-first landing zones.

The module is safe by default. All paid service enablement flags default to
`false`, and service enablement requires this exact acknowledgement:

```text
I approve the recurring security baseline cost and reviewed Terraform plan
```

## Deployment scopes

Run separate plans by account and Region:

- `management-delegation`: management account only; designates delegated
  administrators for GuardDuty, Security Hub, IAM Access Analyzer, Inspector,
  and Macie.
- `security-regional`: security account only; enables regional administrator
  services, aggregation, alert routing, and organization-level settings.
- `member-account`: individual member account only; currently for account-level
  S3 Block Public Access and optional Inspector/Macie member enablement.

Do not combine these into one cross-account provider graph. Use the approved
profile/role for the target account and pass `current_account_id` explicitly.

## Control Tower boundary

This module does not create AWS Config recorders, delivery channels, or
Control Tower managed rules. Config aggregation is disabled while
`control_tower_manages_config = true`, which is the default. Create a Config
organization aggregator only after proving Control Tower does not already own
the aggregator or after approving a non-overlapping read-only aggregation
extension.

## Services covered

- GuardDuty delegated admin, detector, and organization auto-enrollment
- Security Hub delegated admin, account, organization configuration, and finding
  aggregation
- IAM Access Analyzer organization analyzer
- AWS Config organization aggregator where not Control Tower-owned
- S3 account-level Block Public Access
- Optional Inspector delegated admin, enabler, and organization config
- Optional Macie delegated admin, account, and organization config
- EventBridge alert routing for security finding events

## Recurring costs

GuardDuty, Security Hub, Inspector, Macie, AWS Config recording/rules, EventBridge
event volume, SNS/notification targets, and downstream ticketing/SIEM ingestion
can incur recurring costs. AWS Config aggregators have no additional aggregator
charge, but source Config recording and rules remain billable. S3 account-level
Block Public Access has no direct charge.

## Sources

- GuardDuty organizations:
  https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_organizations.html
- Security Hub organizations:
  https://docs.aws.amazon.com/securityhub/latest/userguide/designate-orgs-admin-account.html
- IAM Access Analyzer:
  https://docs.aws.amazon.com/IAM/latest/UserGuide/access-analyzer-getting-started.html
- AWS Config aggregation:
  https://docs.aws.amazon.com/config/latest/developerguide/aggregate-data.html
