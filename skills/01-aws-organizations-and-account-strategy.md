# Skill 01 — AWS Organizations and Account Strategy

## Skill Purpose
Use AWS Organizations to create a governed multi-account AWS environment with clear account boundaries, organizational units, and centralized administrative control.

## What You Must Know

- Difference between management account and member accounts
- Organizational Units and account placement
- Workload isolation using separate accounts
- Delegated administrator model
- Account vending and account baseline process
- SCP inheritance from Root and OUs
- Why the management account should not host workloads

## Account Model for This Project

| Account | Purpose |
|---|---|
| Management | Organization administration only |
| Security | Central security operations and delegated security administration |
| Logging | Central log archive and audit evidence storage |
| Shared Services | Networking, DNS, CI/CD, artifact repositories, shared tools |
| Development | Developer workloads and early testing |
| Staging | Production-like validation environment |
| Production | Live workloads with strict controls |

## Recommended OU Model

```text
Root
├── Security
├── Infrastructure
├── Non-Production
└── Production
```

Alternative:

```text
Root
├── Security OU
├── Logging OU
├── Shared Services OU
├── Development OU
├── Staging OU
└── Production OU
```

Use fewer OUs when the organization is small. Use more OUs when each environment needs different controls.

## Implementation Tasks

1. Create the AWS Organization from the management account.
2. Create OUs for security, infrastructure, non-production, and production.
3. Create or invite the required accounts.
4. Move accounts into correct OUs.
5. Enable trusted access for organization-integrated security services.
6. Assign delegated administrators for security services.
7. Apply baseline SCPs.
8. Document account IDs, account purpose, owner, and environment.

## Terraform Resources to Learn

- `aws_organizations_organization`
- `aws_organizations_organizational_unit`
- `aws_organizations_account`
- `aws_organizations_policy`
- `aws_organizations_policy_attachment`
- `aws_organizations_delegated_administrator`

## Validation Checks

- Confirm all accounts appear under the correct OU.
- Confirm SCPs attached at the intended OU level.
- Confirm security account is delegated administrator where required.
- Confirm no workloads are deployed in the management account.

## Common Mistakes

- Running workloads in the management account.
- Applying restrictive SCPs at Root without testing.
- Creating too many OUs too early.
- Forgetting that SCPs do not grant permissions; they only set permission boundaries.
- Not documenting account ownership and access model.

## Interview Talking Point

> I used AWS Organizations to create a governed multi-account structure. Each account had a clear purpose, such as development, staging, production, logging, security, and shared services. This gave us isolation, clearer ownership, stronger security boundaries, and a scalable foundation for future workloads.


---

## AWS Control Tower Update

In a production enterprise implementation, AWS Control Tower should be considered the preferred way to establish and govern the AWS Organizations baseline.

Use this skill in two ways:

1. **With Control Tower**: use AWS Organizations concepts to understand the OU/account structure that Control Tower creates and governs.
2. **Without Control Tower**: implement the organization, OUs, accounts, and SCPs directly with Terraform for a lab or portfolio project.

When Control Tower is used:

- Do not treat the organization as a purely custom Terraform-managed resource.
- Document which OUs are governed by Control Tower.
- Use Account Factory or AFT for account vending.
- Avoid Terraform changes that conflict with Control Tower-managed baselines.
- Use custom SCPs only where Control Tower controls do not meet the requirement.

Interview talking point:

> AWS Control Tower sits on top of AWS Organizations. I used Organizations to structure the accounts and OUs, while Control Tower provided the governed landing zone baseline and account governance model.

