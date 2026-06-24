# Control Catalog and Custom SCP Gap Analysis

## Status

Reviewed against the official AWS Control Tower Controls Reference Guide on
2026-06-24. This catalog is design and plan evidence, not approval to enable a
control or attach an SCP.

AWS has removed the old static global-identifier table because it was outdated.
Before enablement, use AWS Control Catalog `ListControls`/`GetControl` or the
Control Tower console to resolve the current opaque global control ARN and verify
its behavior, implementation type, Region availability, and parameters. This
repository records published names and documented identifiers without inventing
opaque IDs. See [Control identifiers](https://docs.aws.amazon.com/controltower/latest/controlreference/control-identifiers.html)
and [the current catalog](https://docs.aws.amazon.com/controltower/latest/controlreference/controls-reference.html).

## Requirement mapping

| Requirement | Current native Control Tower mapping | Coverage | Custom SCP decision |
|---|---|---|---|
| CloudTrail protection | Mandatory Control Tower CloudTrail protections for pre-4.0 landing zones; LZ 4.0 centralized-logging bucket protection; strongly recommended account CloudTrail/Lake detective control; `CT.CLOUDTRAIL.PR.2` log-validation proactive control | Covered for Control Tower-owned logging, version-dependent | None. Never duplicate or import the Control Tower trail/baseline |
| Leaving the organization | No equivalent preventive control located in the current catalog | Gap | `deny_leave_organization` |
| Approved Regions | `CT.MULTISERVICE.PV.1`, configurable OU Region deny | Covered | None; use its `AllowedRegions`, `ExemptedPrincipalARNs`, and `ExemptedActions` parameters |
| Public S3 restrictions | `CT.S3.PR.1` requires Block Public Access for supported provisioning; strongly recommended public-read/public-write detective controls | Partial: direct API/runtime tampering remains | `restrict_s3_public_access` for public canned ACLs and BPA tampering |
| Security-service protection | `CT.GUARDDUTY.PR.1` covers detector S3 protection; Security Hub CSPM Service-Managed Standard supplies selected detective controls | Partial: no general disable/disassociate prevention | `protect_security_services` |
| Log Archive protection | LZ 4.0 mandatory unified S3 protection; existing `AWS-GR_AUDIT_BUCKET_*` controls for encryption, logging, policy, and retention lifecycle | Covered for Control Tower buckets | None; non-Control-Tower buckets use owner-specific bucket/KMS policies |
| Root-user restrictions | `AWS-GR_RESTRICT_ROOT_USER_ACCESS_KEYS`, `AWS-GR_RESTRICT_ROOT_USER`, plus root-MFA detective control | Covered | None; enable native preventive controls after recovery review |
| IAM-user restrictions | Elective detective controls for IAM-user MFA and console-user MFA | Partial: detects but does not prohibit users/keys | `restrict_iam_users` |
| Privilege escalation | Mandatory protection for Control Tower/CloudFormation roles and `CT.IAM.PV.1` for the Control Tower Backup role | Partial: protects platform-owned roles only | `restrict_privilege_escalation` |

### CloudTrail and Log Archive version caveat

The [mandatory-controls reference](https://docs.aws.amazon.com/controltower/latest/controlreference/mandatory-controls.html)
states that Landing Zone 4.0 no longer deploys four legacy account-trail controls
and introduces centralized-logging protections. The implementation must query
the actual landing-zone version and enabled controls before relying on either
set. Terraform must not attach the legacy sample policy as a supposed replacement.

### Region handling

The native [OU Region deny control](https://docs.aws.amazon.com/controltower/latest/controlreference/ou-region-deny.html)
already carries AWS's current global-service action exclusions and protects
Control Tower execution/configuration roles. It supports explicit exempt actions
and principals. Maintaining a parallel custom `NotAction` list would drift as AWS
services change and can conflict with landing-zone Region deny evaluation.

### Root and S3 controls

The native root preventive controls and identifiers are listed in [strongly
recommended preventive controls](https://docs.aws.amazon.com/controltower/latest/controlreference/strongly-recommended-preventive-controls.html)
and [elective preventive controls](https://docs.aws.amazon.com/controltower/latest/controlreference/elective-preventive-controls.html).
S3 public-access coverage combines [CT.S3.PR.1](https://docs.aws.amazon.com/controltower/latest/controlreference/s3-rules.html)
with the public-read/public-write controls in [strongly recommended detective
controls](https://docs.aws.amazon.com/controltower/latest/controlreference/strongly-recommended-detective-controls.html).

### Security and IAM gaps

The current [GuardDuty control](https://docs.aws.amazon.com/controltower/latest/controlreference/guard-duty-rules.html)
and [Security Hub CSPM integration](https://docs.aws.amazon.com/controltower/latest/controlreference/security-hub-controls.html)
do not provide general preventive protection against disabling/disassociation.
`CT.IAM.PV.1` protects the [Control Tower Backup role](https://docs.aws.amazon.com/controltower/latest/controlreference/ct-iam-pv-1.html),
not arbitrary escalation paths. Those differences justify the narrow custom
policies.

## Service operations and exception design

Custom conditional SCPs exempt only:

- `AWSControlTowerExecution`, using the documented cross-account role-name
  pattern because the account IDs differ by governed account;
- direct AWS service calls identified by `aws:PrincipalIsAWSService=true`; and
- exact approved IAM role ARNs supplied through configuration.

AWS documents that SCPs do not affect service-linked roles. No custom policy
denies service-linked-role lifecycle APIs. See [SCP effects and exclusions](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html).

The leave-organization policy has no exception. Break-glass, routine admin, and
Terraform roles are not automatically exempt. Every exact exception requires a
business owner, security approver, affected actions, compensating detection,
expiry, and removal plan.

## Unresolved before any attachment

- Current global native-control ARNs and enabled-control inventory.
- Landing-zone version and centralized-logging configuration.
- Approved Regions and native Region-deny parameter values.
- Exact Sandbox, Development, Staging, and Production OU IDs.
- Per-policy exception roles; use separate module instances where they differ.
- S3 account-level Block Public Access baseline evidence.
- GuardDuty/Security Hub delegated-admin lifecycle permissions.
- Identity migration plan for any existing IAM users or access keys.
- Safe soak periods, rollback owner, security alerts, and production approver.
