#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

SCRIPT_NAME="$(basename "$0")"
PROFILE="${AWS_PROFILE:-}"
EXPECTED_MANAGEMENT_ACCOUNT_ID="${EXPECTED_MANAGEMENT_ACCOUNT_ID:-}"
OUTPUT_DIR="${EVIDENCE_DIR:-}"
EXPECTED_OUS=()
EXPECTED_ACCOUNTS=()
TEMP_DIR=""
EVIDENCE_RUN_DIR=""
FAILURES=0

usage() {
  cat <<'USAGE'
Read-only AWS Organizations readiness and evidence validation.

Usage:
  validate-organization.sh [options]

Options:
  --profile NAME                         AWS CLI profile (or AWS_PROFILE)
  --expected-management-account-id ID   Expected 12-digit management account ID
                                        (or EXPECTED_MANAGEMENT_ACCOUNT_ID)
  --expected-ou NAME                    Required OU display name; repeatable
  --expected-account NAME               Required account name; repeatable
  --output-dir PATH                     Write private evidence to a timestamped
                                        directory (or EVIDENCE_DIR)
  -h, --help                            Show this help

Optional comma-separated environment variables:
  EXPECTED_OU_NAMES
  EXPECTED_ACCOUNT_NAMES

The script calls only STS and AWS Organizations read/list/describe APIs. It does
not create, move, invite, close, register, enable, disable, attach, or detach.
Never pass credentials as arguments; use the normal AWS credential chain.
USAGE
}

log() {
  printf '[%s] %s\n' "$SCRIPT_NAME" "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

append_csv_values() {
  local csv="$1"
  local target="$2"
  local values=()
  local value

  [[ -n "$csv" ]] || return 0
  IFS=',' read -r -a values <<<"$csv"
  for value in "${values[@]}"; do
    value="${value#${value%%[![:space:]]*}}"
    value="${value%${value##*[![:space:]]}}"
    [[ -n "$value" ]] || continue
    if [[ "$target" == "ou" ]]; then
      EXPECTED_OUS+=("$value")
    else
      EXPECTED_ACCOUNTS+=("$value")
    fi
  done
}

while (($# > 0)); do
  case "$1" in
    --profile)
      (($# >= 2)) || die "--profile requires a value"
      PROFILE="$2"
      shift 2
      ;;
    --expected-management-account-id)
      (($# >= 2)) || die "--expected-management-account-id requires a value"
      EXPECTED_MANAGEMENT_ACCOUNT_ID="$2"
      shift 2
      ;;
    --expected-ou)
      (($# >= 2)) || die "--expected-ou requires a value"
      EXPECTED_OUS+=("$2")
      shift 2
      ;;
    --expected-account)
      (($# >= 2)) || die "--expected-account requires a value"
      EXPECTED_ACCOUNTS+=("$2")
      shift 2
      ;;
    --output-dir)
      (($# >= 2)) || die "--output-dir requires a value"
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1 (use --help)"
      ;;
  esac
done

append_csv_values "${EXPECTED_OU_NAMES:-}" "ou"
append_csv_values "${EXPECTED_ACCOUNT_NAMES:-}" "account"

if [[ -n "$EXPECTED_MANAGEMENT_ACCOUNT_ID" && ! "$EXPECTED_MANAGEMENT_ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
  die "expected management account ID must contain exactly 12 digits"
fi

command -v aws >/dev/null 2>&1 || die "AWS CLI is required"
command -v jq >/dev/null 2>&1 || die "jq is required"

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/organization-validation.XXXXXX")"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

if [[ -n "$OUTPUT_DIR" ]]; then
  EVIDENCE_RUN_DIR="${OUTPUT_DIR%/}/organization-validation-${TIMESTAMP}"
  mkdir -p "$EVIDENCE_RUN_DIR"
  log "Evidence directory: $EVIDENCE_RUN_DIR"
fi

AWS_ARGS=(--no-cli-pager)
if [[ -n "$PROFILE" ]]; then
  AWS_ARGS+=(--profile "$PROFILE")
fi

run_json() {
  local filename="$1"
  shift
  local path="$TEMP_DIR/$filename"

  log "Read-only query: aws $1 $2"
  if ! aws "${AWS_ARGS[@]}" "$@" --output json >"$path"; then
    die "AWS query failed: aws $1 $2. Check profile, permissions, Organizations membership, and network access."
  fi
  jq . "$path" >"${path}.normalized"
  mv "${path}.normalized" "$path"
}

record_json() {
  local source="$1"
  local destination="$2"
  if [[ -n "$EVIDENCE_RUN_DIR" ]]; then
    cp "$source" "$EVIDENCE_RUN_DIR/$destination"
  fi
}

run_json caller-identity.json sts get-caller-identity
run_json organization.json organizations describe-organization
run_json roots.json organizations list-roots
run_json accounts.json organizations list-accounts
run_json trusted-service-access.json organizations list-aws-service-access-for-organization
run_json delegated-administrators.json organizations list-delegated-administrators
run_json scps.json organizations list-policies --filter SERVICE_CONTROL_POLICY

CALLER_ACCOUNT_ID="$(jq -r '.Account' "$TEMP_DIR/caller-identity.json")"
MANAGEMENT_ACCOUNT_ID="$(jq -r '.Organization.ManagementAccountId // .Organization.MasterAccountId // empty' "$TEMP_DIR/organization.json")"
FEATURE_SET="$(jq -r '.Organization.FeatureSet // empty' "$TEMP_DIR/organization.json")"
ORGANIZATION_ID="$(jq -r '.Organization.Id // empty' "$TEMP_DIR/organization.json")"

[[ -n "$MANAGEMENT_ACCOUNT_ID" ]] || die "Organizations response did not include a management account ID"

if [[ "$CALLER_ACCOUNT_ID" != "$MANAGEMENT_ACCOUNT_ID" ]]; then
  log "ERROR: caller account $CALLER_ACCOUNT_ID is not Organizations management account $MANAGEMENT_ACCOUNT_ID"
  FAILURES=$((FAILURES + 1))
fi

if [[ -n "$EXPECTED_MANAGEMENT_ACCOUNT_ID" && "$MANAGEMENT_ACCOUNT_ID" != "$EXPECTED_MANAGEMENT_ACCOUNT_ID" ]]; then
  log "ERROR: management account mismatch: expected $EXPECTED_MANAGEMENT_ACCOUNT_ID, received $MANAGEMENT_ACCOUNT_ID"
  FAILURES=$((FAILURES + 1))
fi

if [[ "$FEATURE_SET" != "ALL" ]]; then
  log "ERROR: Organizations feature set is '$FEATURE_SET'; Control Tower requires all features"
  FAILURES=$((FAILURES + 1))
fi

ALL_OUS='[]'
QUEUE=()
while IFS= read -r root_id; do
  [[ -n "$root_id" ]] && QUEUE+=("$root_id")
done < <(jq -r '.Roots[]?.Id' "$TEMP_DIR/roots.json")

queue_index=0
page_index=0
while ((queue_index < ${#QUEUE[@]})); do
  parent_id="${QUEUE[$queue_index]}"
  queue_index=$((queue_index + 1))
  page_index=$((page_index + 1))
  page_file="ous-page-${page_index}.json"

  run_json "$page_file" organizations list-organizational-units-for-parent --parent-id "$parent_id"
  PAGE_OUS="$(jq -c '.OrganizationalUnits // []' "$TEMP_DIR/$page_file")"
  ALL_OUS="$(jq -cn --argjson current "$ALL_OUS" --argjson page "$PAGE_OUS" '$current + $page')"

  while IFS= read -r child_id; do
    [[ -n "$child_id" ]] && QUEUE+=("$child_id")
  done < <(jq -r '.OrganizationalUnits[]?.Id' "$TEMP_DIR/$page_file")
done

printf '%s\n' "$ALL_OUS" | jq '{OrganizationalUnits: .}' >"$TEMP_DIR/organizational-units.json"

for expected_ou in "${EXPECTED_OUS[@]}"; do
  if ! jq -e --arg name "$expected_ou" '.OrganizationalUnits[]? | select(.Name == $name)' "$TEMP_DIR/organizational-units.json" >/dev/null; then
    log "ERROR: expected OU not found: $expected_ou"
    FAILURES=$((FAILURES + 1))
  fi
done

for expected_account in "${EXPECTED_ACCOUNTS[@]}"; do
  if ! jq -e --arg name "$expected_account" '.Accounts[]? | select(.Name == $name and ((.State // .Status) == "ACTIVE"))' "$TEMP_DIR/accounts.json" >/dev/null; then
    log "ERROR: expected active account not found: $expected_account"
    FAILURES=$((FAILURES + 1))
  fi
done

record_json "$TEMP_DIR/caller-identity.json" caller-identity.json
record_json "$TEMP_DIR/organization.json" organization.json
record_json "$TEMP_DIR/roots.json" roots.json
record_json "$TEMP_DIR/accounts.json" accounts.json
record_json "$TEMP_DIR/organizational-units.json" organizational-units.json
record_json "$TEMP_DIR/trusted-service-access.json" trusted-service-access.json
record_json "$TEMP_DIR/delegated-administrators.json" delegated-administrators.json
record_json "$TEMP_DIR/scps.json" scps.json

printf 'Organization ID: %s\n' "$ORGANIZATION_ID"
printf 'Management account ID: %s\n' "$MANAGEMENT_ACCOUNT_ID"
printf 'Feature set: %s\n' "$FEATURE_SET"
printf 'Active accounts: %s\n' "$(jq '[.Accounts[]? | select((.State // .Status) == "ACTIVE")] | length' "$TEMP_DIR/accounts.json")"
printf 'Organizational units: %s\n' "$(jq '.OrganizationalUnits | length' "$TEMP_DIR/organizational-units.json")"
printf 'Trusted AWS services: %s\n' "$(jq '.EnabledServicePrincipals | length' "$TEMP_DIR/trusted-service-access.json")"
printf 'Delegated administrators: %s\n' "$(jq '.DelegatedAdministrators | length' "$TEMP_DIR/delegated-administrators.json")"

if ((FAILURES > 0)); then
  die "$FAILURES validation check(s) failed"
fi

log "Organization validation passed"
