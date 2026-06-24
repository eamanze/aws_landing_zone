# Skill 09 — Validation and Audit Evidence

## Skill Purpose
Prove that the AWS landing zone works correctly by collecting validation evidence for account structure, IAM access, logging, guardrails, networking, and Terraform state.

## What You Must Know

- AWS CLI validation
- CloudTrail event lookup
- S3 log inspection
- SCP deny testing
- Cross-account STS role testing
- Terraform plan drift checks
- Evidence capture
- Audit-ready documentation

## Evidence Folder Structure

```text
docs/evidence/
├── 01-organization-structure.md
├── 02-account-list.md
├── 03-scp-deny-tests.md
├── 04-cloudtrail-log-delivery.md
├── 05-cross-account-role-tests.md
├── 06-network-validation.md
├── 07-security-service-aggregation.md
└── 08-terraform-drift-check.md
```

## Required Evidence

| Area | Evidence |
|---|---|
| Organization | Accounts and OUs listed |
| IAM | Successful role assumption output |
| CloudTrail | Logs from all accounts in central bucket |
| SCP | Expected AccessDenied result |
| Networking | VPCs, routes, subnets, and flow logs |
| Security | GuardDuty/Security Hub enabled and aggregated |
| Terraform | No drift after deployment |

## Validation Commands

### Organization

```bash
aws organizations list-accounts
aws organizations list-roots
aws organizations list-organizational-units-for-parent --parent-id <ROOT_ID>
```

### CloudTrail

```bash
aws cloudtrail describe-trails --include-shadow-trails
aws cloudtrail get-trail-status --name <TRAIL_NAME>
aws s3 ls s3://<CENTRAL_LOG_BUCKET>/AWSLogs/ --recursive | head
```

### IAM Role Assumption

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::<ACCOUNT_ID>:role/ReadOnlyRole \
  --role-session-name validation-test
```

### SCP Deny Test

```bash
aws cloudtrail stop-logging --name <TRAIL_NAME>
```

Expected result:

```text
AccessDeniedException
```

### Terraform Drift

```bash
terraform plan -detailed-exitcode
```

Expected result:

```text
No changes. Your infrastructure matches the configuration.
```

## Implementation Tasks

1. Define validation checklist before deployment.
2. Run validation after each environment deployment.
3. Save CLI outputs or screenshots.
4. Document failed tests and fixes.
5. Repeat validation after guardrail changes.
6. Store final evidence in `docs/evidence/`.

## Common Mistakes

- Deploying controls without testing them.
- Not validating member account log delivery.
- Not testing SCPs from a restricted account.
- Not keeping evidence for interviews or audits.
- Treating Terraform apply success as the only proof of success.

## Interview Talking Point

> After deploying the landing zone, I validated the controls instead of assuming they worked. I tested cross-account roles, SCP denies, centralized CloudTrail delivery, networking, and Terraform drift. I saved the evidence so the setup was audit-ready and easy to explain.


---

## AWS Control Tower Evidence Update

When Control Tower is used, collect evidence for both Control Tower governance and Terraform customization.

Additional evidence to collect:

| Area | Evidence |
|---|---|
| Landing zone | Control Tower landing zone status |
| Governed OUs | List of governed OUs and enrolled accounts |
| Controls | Enabled controls per OU |
| Account Factory | Account provisioning record or AFT pipeline evidence |
| Drift | Control Tower drift status plus Terraform drift status |
| Logging | Log Archive bucket receives organization logs |

Useful validation commands:

```bash
aws controltower list-landing-zones
aws controltower list-enabled-controls --target-identifier <OU_ARN>
aws organizations list-accounts
aws organizations list-accounts-for-parent --parent-id <OU_ID>
```

Interview talking point:

> I validated not only Terraform deployment, but also Control Tower governance status, account enrollment, enabled controls, logging delivery, and drift posture.

