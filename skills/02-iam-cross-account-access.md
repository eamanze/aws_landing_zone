# Skill 02 — IAM and Cross-Account Access

## Skill Purpose
Design least-privilege access across multiple AWS accounts using IAM roles, trust policies, permission boundaries, MFA, and federation.

## What You Must Know

- IAM users vs IAM roles
- Role trust policies
- Cross-account role assumption
- Least privilege permissions
- Permission boundaries
- IAM Identity Center or external identity provider federation
- Break-glass access
- MFA requirements
- Temporary credentials and AWS STS

## Required Role Design

| Role | Purpose |
|---|---|
| OrganizationAdminRole | Limited organization administration from trusted administrators |
| TerraformExecutionRole | Infrastructure deployment role used by pipeline or platform team |
| SecurityAuditRole | Read-only access for security review and audit |
| NetworkAdminRole | Network administration in shared services and workload accounts |
| ReadOnlyRole | General troubleshooting and visibility |
| IncidentResponseRole | Emergency investigation and containment |
| BreakGlassAdminRole | Emergency privileged access with strict monitoring |

## Trust Policy Pattern

Example trust policy for a role in a member account that can be assumed by a trusted role in the security account:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::<SECURITY_ACCOUNT_ID>:role/SecurityAuditRole"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    }
  ]
}
```

## Terraform Resources to Learn

- `aws_iam_role`
- `aws_iam_policy`
- `aws_iam_role_policy_attachment`
- `aws_iam_policy_document`
- `aws_iam_account_password_policy`
- `aws_iam_access_analyzer_analyzer`

## Implementation Tasks

1. Define access personas.
2. Create role naming standard.
3. Create cross-account trust policies.
4. Create least-privilege permission policies.
5. Apply MFA requirement to privileged roles.
6. Create break-glass role with alerting and strict monitoring.
7. Test role assumption using AWS CLI.
8. Document access request and review process.

## CLI Validation

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::<TARGET_ACCOUNT_ID>:role/SecurityAuditRole \
  --role-session-name validation-test
```

## Common Mistakes

- Using IAM users for humans instead of federation.
- Creating broad `AdministratorAccess` everywhere.
- Allowing role assumption from `*` principals.
- Not enforcing MFA for privileged access.
- Not monitoring break-glass role usage.
- Hardcoding access keys into Terraform or CI/CD.

## Interview Talking Point

> I created cross-account IAM roles for administration, auditing, Terraform deployment, and incident response. Access was based on least privilege and temporary credentials through role assumption. This reduced the need for long-lived keys and made access easier to audit across accounts.
