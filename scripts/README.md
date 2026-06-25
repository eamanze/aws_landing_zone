# Validation Scripts

This directory will contain the read-only validation and role-assumption scripts listed in `AGENTS.md`.

Scripts must use strict error handling, avoid printing credentials, separate read-only checks from negative tests, and require explicit confirmation before any mutating or denial test.

## Implemented read-only validators

- `validate-organization.sh` inventories the caller, Organization, roots, accounts, OUs, trusted service access, delegated administrators, and SCP metadata. Optional expectations turn missing names or a wrong management account into failures.
- `validate-control-tower.sh` inventories landing zones, landing-zone details, Control Tower-related management roles, and enabled controls for explicitly supplied OU ARNs. It supports pre-deployment `--expect absent` and post-deployment `--expect present` modes.
- `validate-account-placement.sh` validates the canonical five-OU model and checks each registered account's name, state, direct parent OU, and required ownership tags. Its `--dry-run` mode performs local schema checks and prints the exact read-only AWS calls without contacting AWS.
- `validate-cloudtrail.sh` inventories Control Tower logging state, CloudTrail trail status, S3 log bucket controls, governed-account log object presence, and CloudTrail log-file validation using read-only AWS APIs.
- `assume-role.sh` assumes an exact IAM role with the caller's current identity, optionally prompts for MFA without echo, and executes a command with temporary credentials held only in process memory. It never prints or writes the credentials.
- `validate-scp.sh` validates local deny-only SCP JSON and the current 10,240-character limit, inventories existing policies using read-only APIs, performs read-only IAM simulation, and offers a non-mutating EC2 Region-deny dry run. Every negative mode rejects `production`.

Both scripts accept configuration through arguments or documented environment variables, write evidence only when `--output-dir`/`EVIDENCE_DIR` is supplied, use private file permissions, and contain only read/list/get/describe AWS API calls.
