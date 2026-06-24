# Skill 07 — Security Baseline

## Skill Purpose
Establish a repeatable security baseline across all AWS accounts using centralized security services, encryption, detective controls, and incident response access.

## What You Must Know

- AWS Security Hub
- Amazon GuardDuty
- AWS Config
- IAM Access Analyzer
- AWS KMS
- Amazon Inspector where applicable
- Amazon Macie where applicable
- Centralized findings aggregation
- Delegated administrator model
- Incident response roles
- Security alerting and escalation

## Baseline Security Services

| Service | Purpose |
|---|---|
| GuardDuty | Threat detection |
| Security Hub | Centralized security posture management |
| AWS Config | Resource configuration history and rules |
| IAM Access Analyzer | External access and policy analysis |
| KMS | Encryption key management |
| CloudTrail | Audit trail |
| VPC Flow Logs | Network visibility |

## Security Account Responsibilities

- Aggregates Security Hub findings.
- Acts as delegated administrator for GuardDuty.
- Hosts security automation.
- Owns security-audit and incident-response roles.
- Receives alerts from monitored accounts.

## Required Baseline Controls

- CloudTrail enabled across all accounts.
- GuardDuty enabled across all accounts.
- Security Hub enabled across all accounts.
- Public S3 access blocked by default.
- EBS encryption by default where required.
- KMS encryption for sensitive data stores.
- MFA required for privileged access.
- Root user usage monitored.
- Access Analyzer enabled.
- Findings sent to security team or ticketing workflow.

## Terraform Resources to Learn

- `aws_guardduty_detector`
- `aws_guardduty_organization_admin_account`
- `aws_securityhub_account`
- `aws_securityhub_organization_admin_account`
- `aws_config_configuration_recorder`
- `aws_config_delivery_channel`
- `aws_accessanalyzer_analyzer`
- `aws_kms_key`
- `aws_s3_account_public_access_block`

## Implementation Tasks

1. Configure delegated administrator for security services.
2. Enable GuardDuty organization-wide.
3. Enable Security Hub organization-wide.
4. Enable Access Analyzer.
5. Enable baseline AWS Config where required.
6. Apply account-level public access block.
7. Configure KMS baseline.
8. Create alert routing for critical findings.
9. Document incident response roles.

## Validation Checks

```bash
aws guardduty list-detectors
aws securityhub get-enabled-standards
aws accessanalyzer list-analyzers
aws s3control get-public-access-block --account-id <ACCOUNT_ID>
```

## Common Mistakes

- Enabling security services in only one account.
- Not configuring delegated administrators.
- Ignoring non-production accounts.
- Enabling findings without an owner or response process.
- Not documenting exception handling.
- Creating KMS keys without usable key policies.

## Interview Talking Point

> I created a baseline security model across all accounts, with GuardDuty and Security Hub aggregated into the security account. I also enabled audit logging, public access controls, encryption standards, and security roles for investigation and incident response.
