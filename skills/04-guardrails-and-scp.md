# Skill 04 — Guardrails and Service Control Policies

## Skill Purpose
Use Service Control Policies to define preventive governance controls across AWS accounts and Organizational Units.

## What You Must Know

- SCPs define maximum available permissions.
- SCPs do not grant permissions.
- SCPs apply to IAM users and roles in affected accounts.
- SCPs do not affect the management account in the same way as member accounts.
- SCPs inherit from Root to OU to account.
- Explicit deny overrides allow.
- Guardrails should be tested before wide deployment.

## Required Guardrails for This Project

| Guardrail | Purpose |
|---|---|
| Deny CloudTrail tampering | Protect audit trail |
| Deny leaving organization | Keep accounts under governance |
| Restrict unapproved Regions | Control data residency and cost |
| Deny public S3 buckets | Reduce accidental exposure |
| Deny root user actions | Prevent unmanaged privileged activity |
| Deny disabling GuardDuty/Security Hub | Protect security visibility |
| Deny deleting log archive bucket | Preserve audit evidence |
| Deny privilege escalation | Prevent IAM abuse |

## Example SCP — Deny CloudTrail Tampering

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyCloudTrailTampering",
      "Effect": "Deny",
      "Action": [
        "cloudtrail:DeleteTrail",
        "cloudtrail:StopLogging",
        "cloudtrail:UpdateTrail"
      ],
      "Resource": "*"
    }
  ]
}
```

## Example SCP — Deny Leaving Organization

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyLeavingOrganization",
      "Effect": "Deny",
      "Action": "organizations:LeaveOrganization",
      "Resource": "*"
    }
  ]
}
```

## Terraform Resources to Learn

- `aws_organizations_policy`
- `aws_organizations_policy_attachment`
- `aws_iam_policy_document`

## Implementation Tasks

1. Define guardrail requirements.
2. Write SCP JSON policies.
3. Attach policies to sandbox or development OU first.
4. Test expected deny behavior.
5. Document exceptions.
6. Roll out to staging and production OUs.
7. Monitor impact.

## Validation Checks

- Try to stop CloudTrail from a member account and confirm denial.
- Try to create a resource in an unapproved Region and confirm denial.
- Try to create a public S3 bucket and confirm denial.
- Try to leave the organization and confirm denial.

## Common Mistakes

- Applying SCPs at Root without testing.
- Forgetting global services when creating Region restriction SCPs.
- Blocking CI/CD roles unintentionally.
- Assuming SCPs replace IAM policies.
- Not documenting exception process.

## Interview Talking Point

> I implemented SCP guardrails to enforce non-negotiable controls across the organization. For example, member accounts could not disable CloudTrail, leave the organization, create resources in unapproved Regions, or tamper with log storage. This gave the platform team centralized governance without relying on manual enforcement.


---

## AWS Control Tower Controls Update

When AWS Control Tower is used, do not start by writing every guardrail as a custom SCP. First map the requirement to native Control Tower controls.

Control Tower controls can be:

- **Preventive**: block non-compliant actions.
- **Detective**: detect non-compliance after deployment.
- **Proactive**: check resources before they are deployed where supported.

Recommended approach:

```text
Requirement
→ Check if Control Tower has a suitable control
→ Enable native Control Tower control if suitable
→ Add custom SCP only for gaps or stricter business requirements
→ Test in sandbox/development OU
→ Promote to staging/production after validation
```

Common mistake:

- Creating custom SCPs that block AWS Control Tower service-linked roles, account enrollment, drift remediation, or baseline updates.

Interview talking point:

> I treated Control Tower controls as the first governance layer and used custom SCPs only for organization-specific gaps, such as stricter Region restrictions or additional protection around logging resources.

