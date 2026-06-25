#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

usage() {
  cat <<'USAGE'
Usage: validate-cloudtrail.sh --mode MODE [options]

Modes:
  control-tower-inventory  Read-only inventory of landing zones and enabled controls
  trail-status             Read-only CloudTrail trail status and configuration
  bucket-controls          Read-only S3 bucket encryption/versioning/BPA/policy checks
  governed-account-logs    Read-only check for log objects from each governed account
  validate-log-files       Read-only CloudTrail digest/log validation with AWS CLI

Common options:
  --profile NAME           AWS CLI profile, or AWS_PROFILE
  --region REGION          AWS Region for regional API calls
  --output-dir PATH        Private evidence output directory

trail-status:
  --trail-name NAME        CloudTrail trail name or ARN

bucket-controls / governed-account-logs:
  --bucket NAME            S3 log bucket name
  --prefix PREFIX          Optional prefix, default cloudtrail
  --account-id ID          Governed account ID; repeatable

validate-log-files:
  --trail-name NAME        CloudTrail trail name
  --start-time ISO8601     Start time passed to aws cloudtrail validate-logs
  --end-time ISO8601       End time passed to aws cloudtrail validate-logs

This script is read-only. It never creates trails, buckets, keys, recorders, or
policies and never mutates Control Tower resources.
USAGE
}

mode=""
profile="${AWS_PROFILE:-}"
region="${AWS_REGION:-}"
output_dir="${EVIDENCE_DIR:-}"
trail_name=""
bucket=""
prefix="cloudtrail"
start_time=""
end_time=""
account_ids=()

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while (($# > 0)); do
  case "$1" in
    --mode) (($# >= 2)) || die "--mode requires a value"; mode=$2; shift 2 ;;
    --profile) (($# >= 2)) || die "--profile requires a value"; profile=$2; shift 2 ;;
    --region) (($# >= 2)) || die "--region requires a value"; region=$2; shift 2 ;;
    --output-dir) (($# >= 2)) || die "--output-dir requires a value"; output_dir=$2; shift 2 ;;
    --trail-name) (($# >= 2)) || die "--trail-name requires a value"; trail_name=$2; shift 2 ;;
    --bucket) (($# >= 2)) || die "--bucket requires a value"; bucket=$2; shift 2 ;;
    --prefix) (($# >= 2)) || die "--prefix requires a value"; prefix=$2; shift 2 ;;
    --start-time) (($# >= 2)) || die "--start-time requires a value"; start_time=$2; shift 2 ;;
    --end-time) (($# >= 2)) || die "--end-time requires a value"; end_time=$2; shift 2 ;;
    --account-id) (($# >= 2)) || die "--account-id requires a value"; account_ids+=("$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

command -v aws >/dev/null 2>&1 || die "AWS CLI is required"
command -v jq >/dev/null 2>&1 || die "jq is required"

aws_args=(--no-cli-pager)
[[ -z "$profile" ]] || aws_args+=(--profile "$profile")
[[ -z "$region" ]] || aws_args+=(--region "$region")

write_evidence() {
  local name=$1
  local content=$2
  [[ -n "$output_dir" ]] || return 0
  mkdir -p "$output_dir"
  chmod 700 "$output_dir"
  printf '%s\n' "$content" >"$output_dir/$name"
  chmod 600 "$output_dir/$name"
}

require_region() {
  [[ $region =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$ ]] || die "--region is required and must be a valid Region"
}

require_bucket() {
  [[ $bucket =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]] || die "--bucket must be a valid bucket name"
}

case "$mode" in
  control-tower-inventory)
    require_region
    landing_zones=$(aws "${aws_args[@]}" controltower list-landing-zones --output json)
    write_evidence "control-tower-landing-zones.json" "$landing_zones"
    printf '%s\n' "$landing_zones" | jq -r '.landingZones[]? | [.arn, .version, .driftStatus.summaryStatus] | @tsv'
    ;;

  trail-status)
    require_region
    [[ -n "$trail_name" ]] || die "--trail-name is required"
    trails=$(aws "${aws_args[@]}" cloudtrail describe-trails --trail-name-list "$trail_name" --include-shadow-trails --output json)
    status=$(aws "${aws_args[@]}" cloudtrail get-trail-status --name "$trail_name" --output json)
    write_evidence "cloudtrail-${trail_name//[^A-Za-z0-9_.-]/_}-describe.json" "$trails"
    write_evidence "cloudtrail-${trail_name//[^A-Za-z0-9_.-]/_}-status.json" "$status"
    printf '%s\n' "$trails" | jq -e '.trailList | length > 0' >/dev/null || die "trail not found"
    printf '%s\n' "$trails" | jq -r '.trailList[] | {Name, TrailARN, HomeRegion, IsOrganizationTrail, LogFileValidationEnabled, S3BucketName, S3KeyPrefix, KmsKeyId}'
    printf '%s\n' "$status" | jq -r '{IsLogging, LatestDeliveryTime, LatestDeliveryError, LatestDigestDeliveryTime, LatestDigestDeliveryError}'
    ;;

  bucket-controls)
    require_bucket
    encryption=$(aws "${aws_args[@]}" s3api get-bucket-encryption --bucket "$bucket" --output json)
    versioning=$(aws "${aws_args[@]}" s3api get-bucket-versioning --bucket "$bucket" --output json)
    public_access=$(aws "${aws_args[@]}" s3api get-public-access-block --bucket "$bucket" --output json)
    policy_status=$(aws "${aws_args[@]}" s3api get-bucket-policy-status --bucket "$bucket" --output json)
    write_evidence "s3-${bucket}-encryption.json" "$encryption"
    write_evidence "s3-${bucket}-versioning.json" "$versioning"
    write_evidence "s3-${bucket}-public-access-block.json" "$public_access"
    write_evidence "s3-${bucket}-policy-status.json" "$policy_status"
    printf '%s\n' "$versioning" | jq -e '.Status == "Enabled"' >/dev/null || die "bucket versioning is not Enabled"
    printf '%s\n' "$public_access" | jq -e '.PublicAccessBlockConfiguration | .BlockPublicAcls and .IgnorePublicAcls and .BlockPublicPolicy and .RestrictPublicBuckets' >/dev/null || die "bucket public access block is incomplete"
    printf '%s\n' "$policy_status" | jq -e '.PolicyStatus.IsPublic == false' >/dev/null || die "bucket policy is public"
    printf 'PASS: bucket encryption, versioning, public access block, and non-public policy status validated for %s\n' "$bucket"
    ;;

  governed-account-logs)
    require_bucket
    ((${#account_ids[@]} > 0)) || die "at least one --account-id is required"
    for account_id in "${account_ids[@]}"; do
      [[ $account_id =~ ^[0-9]{12}$ ]] || die "invalid account ID: $account_id"
      key_prefix="${prefix%/}/AWSLogs/${account_id}/"
      result=$(aws "${aws_args[@]}" s3api list-objects-v2 --bucket "$bucket" --prefix "$key_prefix" --max-items 1 --output json)
      write_evidence "s3-${bucket}-${account_id}-log-presence.json" "$result"
      count=$(printf '%s\n' "$result" | jq '.Contents // [] | length')
      ((count > 0)) || die "no log objects found for account $account_id under s3://$bucket/$key_prefix"
      printf 'PASS: found log object evidence for account %s under s3://%s/%s\n' "$account_id" "$bucket" "$key_prefix"
    done
    ;;

  validate-log-files)
    require_region
    [[ -n "$trail_name" && -n "$start_time" && -n "$end_time" ]] || die "--trail-name, --start-time, and --end-time are required"
    validation=$(aws "${aws_args[@]}" cloudtrail validate-logs --trail-arn "$trail_name" --start-time "$start_time" --end-time "$end_time" --output json)
    write_evidence "cloudtrail-${trail_name//[^A-Za-z0-9_.-]/_}-validate-logs.json" "$validation"
    printf '%s\n' "$validation" | jq -r '.'
    ;;

  "") die "--mode is required" ;;
  *) die "unsupported mode: $mode" ;;
esac
