# Custom SCP guardrails module

Creates only the custom SCPs identified as gaps in the current AWS Control Tower
catalog. It does not recreate native CloudTrail, Region deny, Log Archive, or
root-user controls. See [`docs/control-catalog.md`](../../../docs/control-catalog.md)
for the mapping and [`docs/scp-risk-report.md`](../../../docs/scp-risk-report.md)
for rollout risks.

## Ownership and safety boundary

- **Owner:** Terraform organization state in the management account.
- **Targets:** existing child OUs only. The module rejects Root IDs and account
  IDs and does not expose a Root attachment input.
- **Default:** all five attachment booleans are `false`; policy creation alone
  does not enforce a deny.
- **Control Tower overlap:** the fixed `AWSControlTowerExecution` role-name
  pattern is exempt from conditional policies. AWS documents that SCPs do not
  restrict service-linked roles; direct AWS service calls are excluded with
  `aws:PrincipalIsAWSService`.
- **Cost:** Organizations SCPs have no direct charge; testing, CloudTrail,
  Config, and security-service operations can incur charges.

## Custom policies

| Key | Why native controls are insufficient | Main risk |
|---|---|---|
| `deny_leave_organization` | No equivalent current Control Tower control was found | Non-negotiable deny; no exception |
| `protect_security_services` | GuardDuty proactive and Security Hub detective controls do not prevent disabling/disassociation | Can block legitimate delegated-admin lifecycle without an approved security role exception |
| `restrict_iam_users` | Native controls detect IAM-user MFA but do not prohibit IAM users or long-lived credentials | Can block approved legacy automation; migrate it before rollout |
| `restrict_privilege_escalation` | Native IAM controls protect selected Control Tower roles, not general privilege-escalation APIs | High operational risk; deployment, security, and incident roles need separately reviewed exact exceptions |
| `restrict_s3_public_access` | Native proactive/detective controls do not fully prevent direct-API Block Public Access tampering | Requires account-level BPA to be enabled first; policy cannot inspect arbitrary bucket-policy JSON |

Exception role ARNs must be exact IAM role ARNs without wildcards. Prefer
`policy_exception_role_arns` so a role is exempted only from the specific custom
policy it must operate. The legacy `approved_exception_role_arns` input remains
available for unusual cases that intentionally need the same exception across
all conditional policies, but it should be avoided in normal rollout. Do not
exempt routine admin or break-glass roles by default. Exceptions require an
owner, reason, affected policy, affected actions, expiry, compensating detection,
and security approval.

## Policy validation

Terraform builds compact JSON with `jsonencode`. Each policy has a lifecycle
precondition enforcing the current AWS Organizations SCP maximum of 10,240
characters. `scripts/validate-scp.sh` additionally validates JSON structure,
deny-only effects, Root-attachment absence, and byte size. AWS notes that SDK/CLI
uploads retain supplied whitespace, so validate the exact document sent.

Sources:

- [AWS Organizations SCP behavior and service-linked-role exclusion](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)
- [AWS Organizations quotas and 10,240-character SCP limit](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_reference_limits.html)
- [Control Tower OU Region deny and exception parameters](https://docs.aws.amazon.com/controltower/latest/controlreference/ou-region-deny.html)

## Rollout

1. Create and review policies with every attachment flag `false`.
2. Resolve exact Sandbox OU ID and exception-role approvals.
3. Enable one policy for Sandbox only; run allowed workflows and safe negative
   tests, then observe at least the approved soak period.
4. Move the same reviewed policy to Development, then Staging, each through a
   new plan and approval.
5. Production requires Gate D approval, evidence from every earlier stage, an
   immediate rollback owner, and a production-specific plan.

Never enable multiple untested policies simultaneously. Do not run denial tests
in production. Stop before apply in this implementation.
