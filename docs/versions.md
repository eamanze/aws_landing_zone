# Tool and Provider Versions

## Pinned baseline

| Component | Repository version | Enforcement |
|---|---:|---|
| Terraform CLI | `1.11.1` | `.terraform-version` and `infra/templates/versions.tf` |
| HashiCorp AWS provider | `6.51.0` | `infra/templates/versions.tf`; copy the complete constraint into every implemented Terraform root/module |

The AWS provider version was selected from the [official Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest). Terraform `1.11.1` matches the installed development binary and supports the S3 backend lockfile approach documented in [HashiCorp's S3 backend documentation](https://developer.hashicorp.com/terraform/language/backend/s3).

Do not run Terraform directly from `infra/` or `infra/templates/`. A deployable root exists only after an environment directory has real configuration and a copied `versions.tf`. Commit the generated `.terraform.lock.hcl` for every deployable root.

## Detected local tools

Detection date: 2026-06-23.

| Tool | Detected version | Status |
|---|---:|---|
| Terraform | `1.11.1` | Available and pinned |
| AWS CLI | `2.15.40` | Available; authentication/account access not tested |
| jq | `1.7.1` | Available |
| Git | `2.50.1` | Available |
| GNU Make | `3.81` | Available |
| TFLint | Not detected | Missing prerequisite for `make lint` |
| Checkov | Not detected | Missing prerequisite for `make security-scan` |
| pre-commit | Not detected | Missing prerequisite for local hooks |
| ShellCheck | Not detected | Optional but recommended for validation scripts |

## Installation commands for missing tools

These commands are documentation only. They were not run.

On macOS with Homebrew:

```bash
brew install tflint
brew install checkov
brew install pre-commit
brew install shellcheck
```

After installation, verify rather than assuming success:

```bash
tflint --version
checkov --version
pre-commit --version
shellcheck --version
```

Install Homebrew only through its official process and only after explicit approval. Alternative installation methods should follow the official projects:

- [TFLint installation](https://github.com/terraform-linters/tflint#installation)
- [Checkov installation](https://www.checkov.io/2.Basics/Installing%20Checkov.html)
- [pre-commit installation](https://pre-commit.com/#install)
- [ShellCheck installation](https://github.com/koalaman/shellcheck#installing)

## Upgrade policy

1. Open a reviewed change that updates `.terraform-version` and `infra/templates/versions.tf` together.
2. Review Terraform and AWS provider upgrade guides, especially major provider changes.
3. Copy the new constraint into every implemented Terraform root and module.
4. Run initialization with `-upgrade` in a non-production branch and commit updated lock files.
5. Run formatting, validation, TFLint, Checkov, tests, and plans for all environments.
6. Promote from development to staging before production.

Do not use floating `latest` versions in deployable Terraform configurations or CI jobs.
