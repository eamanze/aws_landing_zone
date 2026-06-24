#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

usage() {
  cat <<'USAGE'
Usage: validate-scp.sh --mode MODE [options]

Modes:
  validate         Local JSON, deny-only, size, and child-OU target validation
  inventory        Read an existing SCP and its attachments; fails on Root
  simulate         Read-only IAM policy simulation; expects explicitDeny
  region-dry-run   EC2 DescribeInstances --dry-run in a denied Region

Common options:
  --policy-file PATH       SCP JSON file; repeatable for validate
  --target-id OU_ID        Planned child OU target; repeatable for validate
  --profile NAME           AWS CLI profile (or AWS_PROFILE)
  --output-dir PATH        Private evidence directory (or EVIDENCE_DIR)
  -h, --help               Show help

Inventory:
  --policy-id POLICY_ID    Existing Organizations policy ID

Safe negative modes (simulate and region-dry-run):
  --stage STAGE            sandbox, development, or staging; production rejected
  --expected-account-id ID Required caller account assertion

Simulation:
  --policy-file PATH       One SCP JSON document
  --action ACTION          Action expected to receive explicitDeny
  --resource ARN           Resource ARN or *
  --principal-arn ARN      Exact role ARN used as aws:PrincipalArn context

Region dry-run:
  --region REGION          Region expected to be denied

This script never attaches policies and never invokes a mutating denial test.
USAGE
}

mode=""
profile="${AWS_PROFILE:-}"
output_dir="${EVIDENCE_DIR:-}"
policy_id=""
stage=""
expected_account_id=""
action=""
resource="*"
principal_arn=""
region=""
policy_files=()
target_ids=()

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while (($# > 0)); do
  case "$1" in
    --mode)
      (($# >= 2)) || die "--mode requires a value"
      mode=$2
      shift 2
      ;;
    --policy-file)
      (($# >= 2)) || die "--policy-file requires a value"
      policy_files+=("$2")
      shift 2
      ;;
    --target-id)
      (($# >= 2)) || die "--target-id requires a value"
      target_ids+=("$2")
      shift 2
      ;;
    --profile)
      (($# >= 2)) || die "--profile requires a value"
      profile=$2
      shift 2
      ;;
    --output-dir)
      (($# >= 2)) || die "--output-dir requires a value"
      output_dir=$2
      shift 2
      ;;
    --policy-id)
      (($# >= 2)) || die "--policy-id requires a value"
      policy_id=$2
      shift 2
      ;;
    --stage)
      (($# >= 2)) || die "--stage requires a value"
      stage=$2
      shift 2
      ;;
    --expected-account-id)
      (($# >= 2)) || die "--expected-account-id requires a value"
      expected_account_id=$2
      shift 2
      ;;
    --action)
      (($# >= 2)) || die "--action requires a value"
      action=$2
      shift 2
      ;;
    --resource)
      (($# >= 2)) || die "--resource requires a value"
      resource=$2
      shift 2
      ;;
    --principal-arn)
      (($# >= 2)) || die "--principal-arn requires a value"
      principal_arn=$2
      shift 2
      ;;
    --region)
      (($# >= 2)) || die "--region requires a value"
      region=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

contains_only_child_ou_targets() {
  local target
  for target in "${target_ids[@]}"; do
    [[ $target =~ ^ou-[a-z0-9]{4,32}-[a-z0-9]{8,32}$ ]] ||
      die "target must be a child OU ID; Root and account targets are prohibited: $target"
  done
}

validate_policy_file() {
  local file=$1
  local bytes

  [[ -r "$file" ]] || die "policy file is not readable: $file"
  jq -e '
    type == "object" and
    .Version == "2012-10-17" and
    (.Statement | type == "array" and length > 0) and
    all(.Statement[];
      (.Effect == "Deny") and
      ((has("Action") and (.Action | (type == "string" or type == "array"))) or
       (has("NotAction") and (.NotAction | (type == "string" or type == "array")))) and
      has("Resource")
    )
  ' "$file" >/dev/null || die "invalid or non-deny SCP structure: $file"

  bytes=$(LC_ALL=C wc -c <"$file" | tr -d '[:space:]')
  [[ $bytes =~ ^[0-9]+$ ]] || die "unable to calculate policy size: $file"
  ((bytes <= 10240)) || die "policy exceeds the current 10,240-character/byte guardrail: $file ($bytes bytes)"
  printf 'PASS: %s (%s bytes)\n' "$file" "$bytes"
}

require_aws() {
  command -v aws >/dev/null 2>&1 || die "AWS CLI is required for mode $mode"
}

aws_args=(--no-cli-pager)
[[ -z "$profile" ]] || aws_args+=(--profile "$profile")

assert_safe_negative_stage() {
  case "$stage" in
    sandbox|development|staging) ;;
    production) die "denial tests are prohibited in production" ;;
    *) die "--stage must be sandbox, development, or staging for a safe negative mode" ;;
  esac
  [[ $expected_account_id =~ ^[0-9]{12}$ ]] || die "--expected-account-id must contain 12 digits"
  require_aws
  local caller
  caller=$(aws "${aws_args[@]}" sts get-caller-identity --query Account --output text)
  [[ "$caller" == "$expected_account_id" ]] || die "caller account $caller does not match --expected-account-id"
}

command -v jq >/dev/null 2>&1 || die "jq is required"

case "$mode" in
  validate)
    ((${#policy_files[@]} > 0)) || die "validate mode requires at least one --policy-file"
    contains_only_child_ou_targets
    for file in "${policy_files[@]}"; do
      validate_policy_file "$file"
    done
    printf 'PASS: all planned targets are child OUs; no Root attachment is present\n'
    ;;

  inventory)
    require_aws
    [[ $policy_id =~ ^p-[a-zA-Z0-9_]{8,128}$ ]] || die "--policy-id must be a valid Organizations policy ID"
    tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/scp-inventory.XXXXXX")
    trap 'rm -rf "$tmp_dir"' EXIT
    aws "${aws_args[@]}" organizations describe-policy --policy-id "$policy_id" --output json >"$tmp_dir/policy.json"
    aws "${aws_args[@]}" organizations list-targets-for-policy --policy-id "$policy_id" --output json >"$tmp_dir/targets.json"
    jq -e '.Policy.PolicySummary.Type == "SERVICE_CONTROL_POLICY"' "$tmp_dir/policy.json" >/dev/null || die "policy is not an SCP"
    if jq -e '.Targets[]? | select(.Type == "ROOT")' "$tmp_dir/targets.json" >/dev/null; then
      die "SCP is attached to Root; this violates the module rollout policy"
    fi
    if [[ -n "$output_dir" ]]; then
      mkdir -p "$output_dir"
      chmod 700 "$output_dir"
      cp "$tmp_dir/policy.json" "$output_dir/scp-${policy_id}.json"
      cp "$tmp_dir/targets.json" "$output_dir/scp-${policy_id}-targets.json"
      chmod 600 "$output_dir/scp-${policy_id}.json" "$output_dir/scp-${policy_id}-targets.json"
    fi
    printf 'PASS: SCP %s has no Root attachment\n' "$policy_id"
    ;;

  simulate)
    ((${#policy_files[@]} == 1)) || die "simulate mode requires exactly one --policy-file"
    [[ $action =~ ^[a-z0-9-]+:[A-Za-z0-9*]+$ ]] || die "--action is invalid"
    [[ $principal_arn =~ ^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_/-]+$ ]] || die "--principal-arn must be an exact IAM role ARN"
    validate_policy_file "${policy_files[0]}"
    assert_safe_negative_stage
    decision=$(aws "${aws_args[@]}" iam simulate-custom-policy \
      --policy-input-list "file://${policy_files[0]}" \
      --action-names "$action" \
      --resource-arns "$resource" \
      --context-entries \
        "ContextKeyName=aws:PrincipalArn,ContextKeyValues=$principal_arn,ContextKeyType=string" \
        "ContextKeyName=aws:PrincipalIsAWSService,ContextKeyValues=false,ContextKeyType=boolean" \
      --query 'EvaluationResults[0].EvalDecision' \
      --output text)
    [[ "$decision" == "explicitDeny" ]] || die "simulation returned $decision, expected explicitDeny"
    printf 'PASS: read-only simulation returned explicitDeny for %s\n' "$action"
    ;;

  region-dry-run)
    [[ $region =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$ ]] || die "--region is required and must be a valid Region identifier"
    assert_safe_negative_stage
    tmp_error=$(mktemp "${TMPDIR:-/tmp}/scp-region-dry-run.XXXXXX")
    trap 'rm -f "$tmp_error"' EXIT
    if aws "${aws_args[@]}" ec2 describe-instances --region "$region" --dry-run >/dev/null 2>"$tmp_error"; then
      die "EC2 dry-run unexpectedly returned success"
    fi
    if grep -q 'DryRunOperation' "$tmp_error"; then
      die "request is authorized in $region; expected a Region-deny authorization failure"
    fi
    if grep -Eq 'UnauthorizedOperation|AccessDenied|explicit deny|not authorized' "$tmp_error"; then
      printf 'PASS: non-mutating EC2 dry-run was denied in %s; confirm SCP attribution in CloudTrail\n' "$region"
    else
      sed -n '1,8p' "$tmp_error" >&2
      die "dry-run failed for an unexpected reason"
    fi
    ;;

  "") die "--mode is required" ;;
  *) die "unsupported mode: $mode" ;;
esac
