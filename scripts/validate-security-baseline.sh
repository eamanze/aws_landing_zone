#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

usage() {
  cat <<'USAGE'
Usage: validate-security-baseline.sh --mode MODE [options]

Modes:
  guardduty       Read-only GuardDuty detector/org configuration summary
  securityhub     Read-only Security Hub account/org/aggregator summary
  access-analyzer Read-only IAM Access Analyzer list
  config          Read-only AWS Config aggregator list
  s3-bpa          Read-only S3 account public access block check
  inspector       Read-only Inspector delegated admin/account status
  macie           Read-only Macie session/org configuration status

Common options:
  --profile NAME          AWS CLI profile, or AWS_PROFILE
  --region REGION         AWS Region
  --account-id ID         Account ID for S3 Control checks
  --output-dir PATH       Evidence output directory

This script is read-only. It never enables services, changes delegated admins,
creates aggregators, or modifies account settings.
USAGE
}

mode=""
profile="${AWS_PROFILE:-}"
region="${AWS_REGION:-}"
account_id=""
output_dir="${EVIDENCE_DIR:-}"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while (($# > 0)); do
  case "$1" in
    --mode) (($# >= 2)) || die "--mode requires a value"; mode=$2; shift 2 ;;
    --profile) (($# >= 2)) || die "--profile requires a value"; profile=$2; shift 2 ;;
    --region) (($# >= 2)) || die "--region requires a value"; region=$2; shift 2 ;;
    --account-id) (($# >= 2)) || die "--account-id requires a value"; account_id=$2; shift 2 ;;
    --output-dir) (($# >= 2)) || die "--output-dir requires a value"; output_dir=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

command -v aws >/dev/null 2>&1 || die "AWS CLI is required"
command -v jq >/dev/null 2>&1 || die "jq is required"
[[ $region =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$ ]] || die "--region is required and must be valid"

aws_args=(--no-cli-pager --region "$region")
[[ -z "$profile" ]] || aws_args+=(--profile "$profile")

write_evidence() {
  local name=$1
  local content=$2
  [[ -n "$output_dir" ]] || return 0
  mkdir -p "$output_dir"
  chmod 700 "$output_dir"
  printf '%s\n' "$content" >"$output_dir/$name"
  chmod 600 "$output_dir/$name"
}

case "$mode" in
  guardduty)
    detectors=$(aws "${aws_args[@]}" guardduty list-detectors --output json)
    write_evidence "guardduty-detectors-${region}.json" "$detectors"
    printf '%s\n' "$detectors" | jq -r '.DetectorIds[]?' | while read -r detector_id; do
      [[ -n "$detector_id" ]] || continue
      details=$(aws "${aws_args[@]}" guardduty get-detector --detector-id "$detector_id" --output json)
      org_config=$(aws "${aws_args[@]}" guardduty describe-organization-configuration --detector-id "$detector_id" --output json 2>/dev/null || true)
      write_evidence "guardduty-detector-${region}-${detector_id}.json" "$details"
      [[ -z "$org_config" ]] || write_evidence "guardduty-org-config-${region}-${detector_id}.json" "$org_config"
      printf '%s\n' "$details" | jq -r '{DetectorId:"'"$detector_id"'", Status, FindingPublishingFrequency}'
      [[ -z "$org_config" ]] || printf '%s\n' "$org_config" | jq -r '{AutoEnableOrganizationMembers, DataSources}'
    done
    ;;

  securityhub)
    hub=$(aws "${aws_args[@]}" securityhub describe-hub --output json 2>/dev/null || true)
    org=$(aws "${aws_args[@]}" securityhub describe-organization-configuration --output json 2>/dev/null || true)
    agg=$(aws "${aws_args[@]}" securityhub list-finding-aggregators --output json 2>/dev/null || true)
    write_evidence "securityhub-hub-${region}.json" "$hub"
    write_evidence "securityhub-org-${region}.json" "$org"
    write_evidence "securityhub-aggregators-${region}.json" "$agg"
    [[ -z "$hub" ]] || printf '%s\n' "$hub" | jq -r '{HubArn, AutoEnableControls, ControlFindingGenerator}'
    [[ -z "$org" ]] || printf '%s\n' "$org" | jq -r '.'
    [[ -z "$agg" ]] || printf '%s\n' "$agg" | jq -r '.FindingAggregators // []'
    ;;

  access-analyzer)
    analyzers=$(aws "${aws_args[@]}" accessanalyzer list-analyzers --output json)
    write_evidence "access-analyzer-${region}.json" "$analyzers"
    printf '%s\n' "$analyzers" | jq -r '.analyzers[]? | {name, arn, type, status}'
    ;;

  config)
    aggregators=$(aws "${aws_args[@]}" configservice describe-configuration-aggregators --output json)
    status=$(aws "${aws_args[@]}" configservice describe-configuration-aggregator-sources-status --configuration-aggregator-name "${CONFIG_AGGREGATOR_NAME:-organization-config-aggregator}" --output json 2>/dev/null || true)
    write_evidence "config-aggregators-${region}.json" "$aggregators"
    [[ -z "$status" ]] || write_evidence "config-aggregator-status-${region}.json" "$status"
    printf '%s\n' "$aggregators" | jq -r '.ConfigurationAggregators[]? | {ConfigurationAggregatorName, ConfigurationAggregatorArn, OrganizationAggregationSource}'
    [[ -z "$status" ]] || printf '%s\n' "$status" | jq -r '.AggregatedSourceStatusList // []'
    ;;

  s3-bpa)
    [[ $account_id =~ ^[0-9]{12}$ ]] || die "--account-id is required for s3-bpa"
    bpa=$(aws "${aws_args[@]}" s3control get-public-access-block --account-id "$account_id" --output json)
    write_evidence "s3-account-public-access-block-${account_id}.json" "$bpa"
    printf '%s\n' "$bpa" | jq -e '.PublicAccessBlockConfiguration | .BlockPublicAcls and .IgnorePublicAcls and .BlockPublicPolicy and .RestrictPublicBuckets' >/dev/null ||
      die "S3 account-level public access block is incomplete"
    printf 'PASS: S3 account-level public access block is fully enabled for %s\n' "$account_id"
    ;;

  inspector)
    delegated=$(aws "${aws_args[@]}" inspector2 get-delegated-admin-account --output json 2>/dev/null || true)
    status=$(aws "${aws_args[@]}" inspector2 batch-get-account-status --output json 2>/dev/null || true)
    write_evidence "inspector-delegated-admin-${region}.json" "$delegated"
    write_evidence "inspector-account-status-${region}.json" "$status"
    [[ -z "$delegated" ]] || printf '%s\n' "$delegated" | jq -r '.'
    [[ -z "$status" ]] || printf '%s\n' "$status" | jq -r '.'
    ;;

  macie)
    session=$(aws "${aws_args[@]}" macie2 get-macie-session --output json 2>/dev/null || true)
    org=$(aws "${aws_args[@]}" macie2 describe-organization-configuration --output json 2>/dev/null || true)
    admin=$(aws "${aws_args[@]}" macie2 get-administrator-account --output json 2>/dev/null || true)
    write_evidence "macie-session-${region}.json" "$session"
    write_evidence "macie-org-${region}.json" "$org"
    write_evidence "macie-admin-${region}.json" "$admin"
    [[ -z "$session" ]] || printf '%s\n' "$session" | jq -r '.'
    [[ -z "$org" ]] || printf '%s\n' "$org" | jq -r '.'
    [[ -z "$admin" ]] || printf '%s\n' "$admin" | jq -r '.'
    ;;

  "") die "--mode is required" ;;
  *) die "unsupported mode: $mode" ;;
esac
