#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<'USAGE'
Usage: validate-account-placement.sh [options]

Read-only validation of Control Tower-vended account placement and tags.

Options:
  --registry-file PATH   Local registry JSON (or ACCOUNT_REGISTRY_FILE)
  --profile NAME         AWS CLI profile (or AWS_PROFILE)
  --region REGION        AWS CLI Region (or AWS_REGION/AWS_DEFAULT_REGION)
  --output-dir PATH      Write sanitized JSON evidence (or EVIDENCE_DIR)
  --dry-run              Validate local structure and print AWS calls only
  -h, --help             Show this help

The script calls only sts:GetCallerIdentity and Organizations Describe/List APIs.
It never creates, moves, updates, tags, or enrolls accounts.
USAGE
}

registry_file="${ACCOUNT_REGISTRY_FILE:-}"
profile="${AWS_PROFILE:-}"
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
output_dir="${EVIDENCE_DIR:-}"
dry_run=false

while (($# > 0)); do
  case "$1" in
    --registry-file)
      (($# >= 2)) || { echo "ERROR: --registry-file requires a value" >&2; exit 2; }
      registry_file=$2
      shift 2
      ;;
    --profile)
      (($# >= 2)) || { echo "ERROR: --profile requires a value" >&2; exit 2; }
      profile=$2
      shift 2
      ;;
    --region)
      (($# >= 2)) || { echo "ERROR: --region requires a value" >&2; exit 2; }
      region=$2
      shift 2
      ;;
    --output-dir)
      (($# >= 2)) || { echo "ERROR: --output-dir requires a value" >&2; exit 2; }
      output_dir=$2
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ -n "$registry_file" ]] || { echo "ERROR: --registry-file or ACCOUNT_REGISTRY_FILE is required" >&2; exit 2; }
[[ -r "$registry_file" ]] || { echo "ERROR: registry is not readable: $registry_file" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 1; }
jq empty "$registry_file" >/dev/null

required_ou_keys='["security","infrastructure","non_production","production","sandbox"]'
required_account_keys='["security","log_archive","shared_services","development","staging","production"]'
allowed_account_keys='["security","log_archive","shared_services","development","staging","production","sandbox"]'

jq -e \
  --argjson required_ous "$required_ou_keys" \
  --argjson required_accounts "$required_account_keys" \
  --argjson allowed_accounts "$allowed_account_keys" '
  (.organization_id | type == "string" and length > 0) and
  (.management_account_id | type == "string" and length > 0) and
  (.root_id | type == "string" and length > 0) and
  (.ous | type == "object") and
  ((.ous | keys | sort) == ($required_ous | sort)) and
  ([.ous[] | select((.id | type != "string" or length == 0) or (.name | type != "string" or length == 0))] | length == 0) and
  (.accounts | type == "object") and
  (($required_accounts - (.accounts | keys)) | length == 0) and
  (((.accounts | keys) - $allowed_accounts) | length == 0) and
  ([.accounts[] |
    select(
      (.id | type != "string" or length == 0) or
      (.name | type != "string" or length == 0) or
      (.ou_key | type != "string" or ($required_ous | index(.) | not)) or
      (.owner | type != "string" or length == 0) or
      (.environment | type != "string" or length == 0) or
      (.cost_center | type != "string" or length == 0) or
      (.managed_by | type != "string" or length == 0)
    )
  ] | length == 0) and
  ([.accounts[].id] | length == (unique | length))
' "$registry_file" >/dev/null || {
  echo "ERROR: registry structure, canonical OU keys, account mapping, ownership fields, or ID uniqueness is invalid" >&2
  exit 2
}

if [[ $(jq -r '.ous.security.name' "$registry_file") != "Security" ||
      $(jq -r '.ous.infrastructure.name' "$registry_file") != "Infrastructure" ||
      $(jq -r '.ous.non_production.name' "$registry_file") != "Non-Production" ||
      $(jq -r '.ous.production.name' "$registry_file") != "Production" ||
      $(jq -r '.ous.sandbox.name' "$registry_file") != "Sandbox" ]]; then
  echo "ERROR: canonical OU names must be Security, Infrastructure, Non-Production, Production, and Sandbox" >&2
  exit 2
fi

if $dry_run; then
  echo "DRY RUN: local registry structure is valid; no AWS API calls were made."
  echo "Read-only calls that a live validation would issue:"
  echo "  aws sts get-caller-identity"
  echo "  aws organizations describe-organization"
  echo "  aws organizations list-roots"
  while IFS=$'\t' read -r ou_key ou_id; do
    printf '  aws organizations describe-organizational-unit --organizational-unit-id %s  # %s\n' "$ou_id" "$ou_key"
    printf '  aws organizations list-parents --child-id %s\n' "$ou_id"
  done < <(jq -r '.ous | to_entries[] | [.key, .value.id] | @tsv' "$registry_file")
  while IFS=$'\t' read -r account_key account_id; do
    printf '  aws organizations describe-account --account-id %s  # %s\n' "$account_id" "$account_key"
    printf '  aws organizations list-parents --child-id %s\n' "$account_id"
    printf '  aws organizations list-tags-for-resource --resource-id %s\n' "$account_id"
  done < <(jq -r '.accounts | to_entries[] | [.key, .value.id] | @tsv' "$registry_file")
  exit 0
fi

command -v aws >/dev/null 2>&1 || { echo "ERROR: AWS CLI is required for live validation" >&2; exit 1; }

organization_id=$(jq -r '.organization_id' "$registry_file")
management_account_id=$(jq -r '.management_account_id' "$registry_file")
root_id=$(jq -r '.root_id' "$registry_file")

[[ $organization_id =~ ^o-[a-z0-9]{10,32}$ ]] || { echo "ERROR: invalid organization_id" >&2; exit 2; }
[[ $management_account_id =~ ^[0-9]{12}$ ]] || { echo "ERROR: invalid management_account_id" >&2; exit 2; }
[[ $root_id =~ ^r-[a-z0-9]{4,32}$ ]] || { echo "ERROR: invalid root_id" >&2; exit 2; }

aws_args=()
[[ -z "$profile" ]] || aws_args+=(--profile "$profile")
[[ -z "$region" ]] || aws_args+=(--region "$region")

aws_read() {
  aws "${aws_args[@]}" "$@" --no-cli-pager
}

failures=0
results_file=$(mktemp)
trap 'rm -f "$results_file"' EXIT
printf '[]\n' >"$results_file"

caller_account=$(aws_read sts get-caller-identity --query Account --output text)
if [[ "$caller_account" != "$management_account_id" ]]; then
  echo "ERROR: caller account $caller_account is not expected management account $management_account_id" >&2
  exit 1
fi

actual_org=$(aws_read organizations describe-organization --query 'Organization.{Id:Id,ManagementAccountId:MasterAccountId,FeatureSet:FeatureSet}' --output json)
actual_org_id=$(jq -r '.Id' <<<"$actual_org")
actual_management_id=$(jq -r '.ManagementAccountId' <<<"$actual_org")
feature_set=$(jq -r '.FeatureSet' <<<"$actual_org")
[[ "$actual_org_id" == "$organization_id" ]] || { echo "ERROR: Organization ID mismatch" >&2; ((failures += 1)); }
[[ "$actual_management_id" == "$management_account_id" ]] || { echo "ERROR: management account mismatch" >&2; ((failures += 1)); }
[[ "$feature_set" == "ALL" ]] || { echo "ERROR: Organizations all-features mode is not enabled" >&2; ((failures += 1)); }

actual_roots=$(aws_read organizations list-roots --query 'Roots[].Id' --output json)
jq -e --arg root "$root_id" 'index($root) != null' <<<"$actual_roots" >/dev/null || {
  echo "ERROR: configured root_id was not returned by Organizations" >&2
  ((failures += 1))
}

while IFS=$'\t' read -r ou_key ou_id expected_name; do
  [[ $ou_id =~ ^ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}$ ]] || { echo "ERROR: invalid OU ID for $ou_key" >&2; exit 2; }
  actual_ou=$(aws_read organizations describe-organizational-unit --organizational-unit-id "$ou_id" --query 'OrganizationalUnit.{Id:Id,Name:Name}' --output json)
  actual_name=$(jq -r '.Name' <<<"$actual_ou")
  ou_parent=$(aws_read organizations list-parents --child-id "$ou_id" --query 'Parents' --output json)
  if [[ "$actual_name" != "$expected_name" ]] ||
     [[ $(jq 'length' <<<"$ou_parent") -ne 1 ]] ||
     [[ $(jq -r '.[0].Id' <<<"$ou_parent") != "$root_id" ]] ||
     [[ $(jq -r '.[0].Type' <<<"$ou_parent") != "ROOT" ]]; then
    echo "ERROR: OU $ou_key does not match its expected name or direct root placement" >&2
    ((failures += 1))
  fi
done < <(jq -r '.ous | to_entries[] | [.key, .value.id, .value.name] | @tsv' "$registry_file")

while IFS=$'\t' read -r account_key account_id expected_name ou_key owner environment cost_center managed_by; do
  [[ $account_id =~ ^[0-9]{12}$ ]] || { echo "ERROR: invalid account ID for $account_key" >&2; exit 2; }
  expected_ou_id=$(jq -r --arg key "$ou_key" '.ous[$key].id' "$registry_file")
  account=$(aws_read organizations describe-account --account-id "$account_id" --query 'Account.{Id:Id,Name:Name,Status:Status,State:State}' --output json)
  parents=$(aws_read organizations list-parents --child-id "$account_id" --query 'Parents' --output json)
  tags=$(aws_read organizations list-tags-for-resource --resource-id "$account_id" --query 'Tags' --output json)
  state=$(jq -r '.State // .Status' <<<"$account")
  name_matches=$(jq -e --arg name "$expected_name" '.Name == $name' <<<"$account" >/dev/null && echo true || echo false)
  placement_matches=$(jq -e --arg ou "$expected_ou_id" 'length == 1 and .[0].Type == "ORGANIZATIONAL_UNIT" and .[0].Id == $ou' <<<"$parents" >/dev/null && echo true || echo false)
  tags_match=$(jq -e \
    --arg project "multi-account-landing-zone" \
    --arg environment "$environment" \
    --arg owner "$owner" \
    --arg cost_center "$cost_center" \
    --arg managed_by "$managed_by" '
      (map({key: .Key, value: .Value}) | from_entries) as $tags |
      $tags.Project == $project and
      $tags.Environment == $environment and
      $tags.Owner == $owner and
      $tags.CostCenter == $cost_center and
      $tags.ManagedBy == $managed_by
    ' <<<"$tags" >/dev/null && echo true || echo false)

  if [[ "$state" != "ACTIVE" || "$name_matches" != true || "$placement_matches" != true || "$tags_match" != true ]]; then
    echo "ERROR: validation failed for account key $account_key" >&2
    ((failures += 1))
  fi

  jq \
    --arg key "$account_key" \
    --arg id "$account_id" \
    --arg state "$state" \
    --argjson name_matches "$name_matches" \
    --argjson placement_matches "$placement_matches" \
    --argjson tags_match "$tags_match" \
    '. + [{account_key:$key, account_id:$id, state:$state, name_matches:$name_matches, placement_matches:$placement_matches, tags_match:$tags_match}]' \
    "$results_file" >"${results_file}.next"
  mv "${results_file}.next" "$results_file"
done < <(jq -r '.accounts | to_entries[] | [.key, .value.id, .value.name, .value.ou_key, .value.owner, .value.environment, .value.cost_center, .value.managed_by] | @tsv' "$registry_file")

if [[ -n "$output_dir" ]]; then
  mkdir -p "$output_dir"
  chmod 700 "$output_dir"
  evidence_file="$output_dir/account-placement-$(date -u +%Y%m%dT%H%M%SZ).json"
  jq \
    --arg checked_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg organization_id "$organization_id" \
    --arg root_id "$root_id" \
    --argjson failures "$failures" \
    --slurpfile results "$results_file" \
    '{checked_at:$checked_at, organization_id:$organization_id, root_id:$root_id, failures:$failures, accounts:$results[0]}' \
    /dev/null >"$evidence_file"
  chmod 600 "$evidence_file"
  echo "Sanitized evidence written to: $evidence_file"
fi

if ((failures > 0)); then
  echo "FAILED: $failures placement or metadata check(s) failed" >&2
  exit 1
fi

echo "PASS: canonical OU structure and all registered account placements/tags match"
