# IAM cross-account roles module

Creates a selected set of canonical landing-zone IAM roles with exact trust
principals, optional permission boundaries, managed-policy attachments, and one
validated inline permissions policy per role.

## Ownership and scope

- **Owner:** Terraform account-baseline state for the target account.
- **Deployment account:** each enrolled member or management account, using a
  separate environment state and provider.
- **Region:** IAM is global; the provider Region is still configured by the root.
- **Control Tower overlap:** none expected. Do not configure a canonical name if
  Control Tower or another StackSet already owns that role.
- **Cost:** IAM roles and policies have no direct recurring charge. CloudTrail,
  EventBridge, and the alert destination used for monitoring can incur charges.

## Identity model

Routine human access should use IAM Identity Center permission sets assigned
directly to accounts. Do not create these roles merely to mirror permission
sets. Human-mode roles exist for justified cross-account or emergency paths;
they accept only exact IAM role ARNs and require MFA in the `AssumeRole` request.
If an Identity Center session cannot satisfy that MFA context, use the permission
set directly rather than weakening the trust policy.

`TerraformExecutionRole` requires exact OIDC provider, issuer, audience, and
subject values. Wildcard subjects are rejected. CI obtains temporary credentials
with `AssumeRoleWithWebIdentity`; no access keys are created or accepted by this
module. Automation roles explicitly reject MFA because non-human identities
cannot supply an MFA token.

`AFTExecutionRole` is rejected when `enable_aft=false` and required when it is
true. Its trust must contain exact IAM role ARNs from the approved AFT management
account.

See AWS guidance for [IAM Identity Center permission sets](https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsetsconcept.html),
[IAM role trust principals](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_principal.html),
[MFA-protected API access](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_configure-api-require.html),
and [OIDC federation condition keys](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_iam-condition-keys.html#condition-keys-wif).

## Permission model

The module does not guess Terraform or AFT permissions. Every role must receive
at least one exact managed-policy ARN or valid inline IAM policy. Callers are
responsible for narrowing actions and resources to the deployed account baseline.
Permission boundaries cap identity-policy permissions but do not grant access.

Broad permissions require a documented exception. In the account-baseline
wrapper, `BreakGlassAdminRole` is the only default attachment of
`AdministratorAccess`; it requires an explicit acknowledgement and monitoring.
AWS-managed `ReadOnlyAccess`, `SecurityAudit`, and Network Administrator policies
are convenient baselines but must still be reviewed because AWS can update
managed policies. Customer-managed policies are preferred when stable,
resource-level scoping is required.

## Validation guarantees

- Only canonical role keys are accepted.
- AWS trust principals must be exact IAM role ARNs; `*`, account root, IAM users,
  and STS session ARNs are rejected.
- Human roles require MFA; automation roles must not require it.
- Terraform execution requires exact OIDC trust with no wildcard values.
- AFT role creation exactly follows `enable_aft`.
- Policy and boundary ARNs must be exact; inline policies must parse as IAM JSON.
- Session duration is constrained to IAM's 1–12 hour range.

Run `terraform test` in this directory for mocked plan-time trust-policy tests.
No test applies resources.
