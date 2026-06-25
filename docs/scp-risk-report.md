# Custom SCP Plan Risk Report

## Decision status

**Status:** planned only; approval required before attachment or negative testing.

The module creates five Terraform-owned policies but defaults every attachment
flag to `false`. It cannot attach to Root because it accepts only IDs matching
the child-OU format. SCPs do not protect the management account, do not grant
permissions, and an explicit deny overrides IAM permissions and boundaries.

## Risk register

| Policy | Risk | Failure signal | Required mitigation and rollback |
|---|---|---|---|
| Deny leaving organization | Low operational, high governance value | A legitimate organization migration is blocked | Detach from the specific child OU only under migration approval; never add a permanent exception |
| Protect security services | High | Delegated-admin updates, member lifecycle, or incident automation receives AccessDenied | Exempt one exact security automation role; validate delegated-admin workflows; detach this policy from the affected OU on unexplained failure |
| Restrict IAM users | Medium/high where legacy identities exist | User/key provisioning or rotation fails | Inventory and migrate every IAM user/key to Identity Center, workload roles, or OIDC before attachment |
| Restrict privilege escalation | Critical | Terraform, CloudFormation, Identity Center provisioning, incident response, or role maintenance fails | Model exact execution roles; test allowed paths; attach this policy alone; retain a management-account rollback operator unaffected by SCPs |
| Restrict S3 public access | Medium | Approved Terraform cannot configure BPA or an application expects ACLs | Enable account-level BPA first; exempt only the exact bucket-baseline role; migrate ACL-dependent applications |

Residual risks:

- An SCP cannot inspect arbitrary S3 bucket-policy JSON to determine whether a
  new policy is public. Account-level BPA plus native proactive/detective controls
  remain required.
- Policy-specific exceptions are supported and should be used by default. The
  legacy global exception input should require explicit security approval because
  it exempts the role from every conditional custom SCP.
- Control Tower control and custom SCP denies accumulate. Detaching the custom
  policy may not remove a deny imposed by a native/inherited control.
- The project does not yet have approved real OU IDs, role ARNs, soak periods,
  or production rollback owners.

## Size and structure validation

AWS Organizations currently permits 10,240 characters per SCP policy document.
Terraform uses compact `jsonencode`, enforces the limit before policy creation,
and outputs each size. The validation script checks the exact file byte count,
JSON version, statements, deny-only effects, and forbidden Root attachments.
See [Organizations quotas](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_reference_limits.html).

## Rollout gates

### 1. Sandbox

1. Confirm the Sandbox OU contains no production workloads or shared platform
   dependencies.
2. Create policies with attachments disabled and review plan/size outputs.
3. Enable one attachment flag for Sandbox only.
4. Obtain Gate D approval, apply from protected CI, and validate Control Tower
   baseline health.
5. Run read-only policy simulation and the Region API dry-run only. Do not run
   destructive denial tests.
6. Test normal Identity Center, Terraform, security, logging, and recovery paths.
7. Observe CloudTrail and support tickets for the approved soak period.

### 2. Development

Promote the unchanged policy document to Development only after Sandbox evidence
passes. Repeat allowed-path tests using Development identities and workloads.
Any new exception returns the policy to Sandbox.

### 3. Staging

Promote the same reviewed policy and exception set to Staging. Exercise
production-like CI, security administration, incident response, account updates,
and Control Tower drift remediation. Rehearse detachment rollback.

### 4. Production

Production requires evidence from all prior stages, a fresh production plan,
named security/platform approvers, a maintenance window, an immediate rollback
operator, and post-attachment monitoring. **Never run a denial test in
Production.** Validate only normal allowed workflows and passive telemetry.

## Approval checkpoint

- [ ] Native control ARNs and enabled states verified through Control Catalog.
- [ ] Control Tower landing-zone version and health recorded.
- [ ] Policy-specific Sandbox OU target approved.
- [ ] Each exception role independently justified and time-bounded.
- [ ] SCP size, syntax, and mock plan checks pass.
- [ ] Allowed-path and safe negative-test plan approved.
- [ ] Rollback command, operator, and evidence directory approved.
- [ ] No Root attachment appears in the plan.
- [ ] Production denial testing is explicitly prohibited in the change record.
