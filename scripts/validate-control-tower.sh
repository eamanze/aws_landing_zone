#!/usr/bin/env bash
set -Eeuo pipefail

umask 077

SCRIPT_NAME="$(basename "$0")"
PROFILE="${AWS_PROFILE:-}"
HOME_REGION="${CONTROL_TOWER_HOME_REGION:-${AWS_REGION:-}}"
EXPECTATION="${CONTROL_TOWER_EXPECT:-either}"
LANDING_ZONE_IDENTIFIER="${CONTROL_TOWER_LANDING_ZONE_IDENTIFIER:-}"
OUTPUT_DIR="${EVIDENCE_DIR:-}"
TARGET_OU_ARNS=()
TEMP_DIR=""
EVIDENCE_RUN_DIR=""
FAILURES=0

usage() {
  cat <<'USAGE'
Read-only AWS Control Tower landing-zone and enabled-control validation.

Usage:
  validate-control-tower.sh --home-region REGION [options]

Options:
  --profile NAME                    AWS CLI profile (or AWS_PROFILE)
  --home-region REGION              Control Tower home Region
                                    (or CONTROL_TOWER_HOME_REGION/AWS_REGION)
  --expect absent|present|either    Expected landing-zone state
                                    (or CONTROL_TOWER_EXPECT; default either)
  --landing-zone-identifier ARN     Validate this landing zone explicitly
  --target-ou-arn ARN               List enabled controls for an OU; repeatable
  --output-dir PATH                 Write private evidence to a timestamped
                                    directory (or EVIDENCE_DIR)
  -h, --help                       Show this help

Optional comma-separated environment variable:
  CONTROL_TOWER_TARGET_OU_ARNS

The script calls only STS/IAM/Control Tower read/list/get APIs. It does not
create, update, reset, delete, enable, disable, register, or deregister.
Never pass credentials or session tokens as arguments.
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

append_ou_csv() {
  local csv="$1"
  local values=()
  local value

  [[ -n "$csv" ]] || return 0
  IFS=',' read -r -a values <<<"$csv"
  for value in "${values[@]}"; do
    value="${value#${value%%[![:space:]]*}}"
    value="${value%${value##*[![:space:]]}}"
    [[ -n "$value" ]] && TARGET_OU_ARNS+=("$value")
  done
}

while (($# > 0)); do
  case "$1" in
    --profile)
      (($# >= 2)) || die "--profile requires a value"
      PROFILE="$2"
      shift 2
      ;;
    --home-region)
      (($# >= 2)) || die "--home-region requires a value"
      HOME_REGION="$2"
      shift 2
      ;;
    --expect)
      (($# >= 2)) || die "--expect requires a value"
      EXPECTATION="$2"
      shift 2
      ;;
    --landing-zone-identifier)
      (($# >= 2)) || die "--landing-zone-identifier requires a value"
      LANDING_ZONE_IDENTIFIER="$2"
      shift 2
      ;;
    --target-ou-arn)
      (($# >= 2)) || die "--target-ou-arn requires a value"
      TARGET_OU_ARNS+=("$2")
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

append_ou_csv "${CONTROL_TOWER_TARGET_OU_ARNS:-}"

[[ -n "$HOME_REGION" ]] || die "--home-region or CONTROL_TOWER_HOME_REGION is required"
[[ "$HOME_REGION" =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$ ]] || die "invalid AWS Region: $HOME_REGION"
case "$EXPECTATION" in
  absent | present | either) ;;
  *) die "--expect must be absent, present, or either" ;;
esac

command -v aws >/dev/null 2>&1 || die "AWS CLI is required"
command -v jq >/dev/null 2>&1 || die "jq is required"

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/control-tower-validation.XXXXXX")"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

if [[ -n "$OUTPUT_DIR" ]]; then
  EVIDENCE_RUN_DIR="${OUTPUT_DIR%/}/control-tower-validation-${TIMESTAMP}"
  mkdir -p "$EVIDENCE_RUN_DIR"
  log "Evidence directory: $EVIDENCE_RUN_DIR"
fi

AWS_ARGS=(--no-cli-pager --region "$HOME_REGION")
if [[ -n "$PROFILE" ]]; then
  AWS_ARGS+=(--profile "$PROFILE")
fi

run_json() {
  local filename="$1"
  shift
  local path="$TEMP_DIR/$filename"

  log "Read-only query: aws $1 $2"
  if ! aws "${AWS_ARGS[@]}" "$@" --output json >"$path"; then
    die "AWS query failed: aws $1 $2. Check profile, Region, CLI version, permissions, and network access."
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
run_json landing-zones.json controltower list-landing-zones
run_json all-roles.json iam list-roles

jq '{Roles: [.Roles[]? | select(.RoleName | test("^(AWSControlTower|AWSServiceRoleForAWSControlTower)"))]}' \
  "$TEMP_DIR/all-roles.json" >"$TEMP_DIR/management-service-roles.json"

LANDING_ZONE_COUNT="$(jq '.landingZones | length' "$TEMP_DIR/landing-zones.json")"

case "$EXPECTATION" in
  absent)
    if ((LANDING_ZONE_COUNT != 0)); then
      log "ERROR: expected no landing zone, found $LANDING_ZONE_COUNT"
      FAILURES=$((FAILURES + 1))
    fi
    ;;
  present)
    if ((LANDING_ZONE_COUNT == 0)) && [[ -z "$LANDING_ZONE_IDENTIFIER" ]]; then
      log "ERROR: expected a landing zone, but none was returned"
      FAILURES=$((FAILURES + 1))
    fi
    ;;
esac

LANDING_ZONE_IDS=()
if [[ -n "$LANDING_ZONE_IDENTIFIER" ]]; then
  LANDING_ZONE_IDS+=("$LANDING_ZONE_IDENTIFIER")
else
  while IFS= read -r identifier; do
    [[ -n "$identifier" ]] && LANDING_ZONE_IDS+=("$identifier")
  done < <(jq -r '.landingZones[]? | if type == "string" then . else .arn end' "$TEMP_DIR/landing-zones.json")
fi

lz_index=0
for identifier in "${LANDING_ZONE_IDS[@]}"; do
  lz_index=$((lz_index + 1))
  run_json "landing-zone-${lz_index}.json" controltower get-landing-zone --landing-zone-identifier "$identifier"
  record_json "$TEMP_DIR/landing-zone-${lz_index}.json" "landing-zone-${lz_index}.json"

  STATUS="$(jq -r '.landingZone.status // empty' "$TEMP_DIR/landing-zone-${lz_index}.json")"
  DRIFT_STATUS="$(jq -r '.landingZone.driftStatus.status // .landingZone.driftStatus // empty' "$TEMP_DIR/landing-zone-${lz_index}.json")"
  VERSION="$(jq -r '.landingZone.version // empty' "$TEMP_DIR/landing-zone-${lz_index}.json")"
  log "Landing zone $lz_index: version=${VERSION:-unknown} status=${STATUS:-unknown} drift=${DRIFT_STATUS:-unknown}"

  if [[ "$EXPECTATION" == "present" && -n "$STATUS" && "$STATUS" != "ACTIVE" ]]; then
    log "ERROR: landing zone status is '$STATUS', expected ACTIVE"
    FAILURES=$((FAILURES + 1))
  fi
done

ou_index=0
for ou_arn in "${TARGET_OU_ARNS[@]}"; do
  [[ "$ou_arn" == arn:*:organizations::*:ou/* ]] || die "invalid target OU ARN format: $ou_arn"
  ou_index=$((ou_index + 1))
  run_json "enabled-controls-${ou_index}.json" controltower list-enabled-controls --target-identifier "$ou_arn"
  record_json "$TEMP_DIR/enabled-controls-${ou_index}.json" "enabled-controls-${ou_index}.json"
done

record_json "$TEMP_DIR/caller-identity.json" caller-identity.json
record_json "$TEMP_DIR/landing-zones.json" landing-zones.json
record_json "$TEMP_DIR/management-service-roles.json" management-service-roles.json

printf 'Caller account ID: %s\n' "$(jq -r '.Account' "$TEMP_DIR/caller-identity.json")"
printf 'Control Tower home Region queried: %s\n' "$HOME_REGION"
printf 'Landing zones returned: %s\n' "$LANDING_ZONE_COUNT"
printf 'Control Tower-related management roles: %s\n' "$(jq '.Roles | length' "$TEMP_DIR/management-service-roles.json")"
printf 'OU control targets queried: %s\n' "${#TARGET_OU_ARNS[@]}"

if ((FAILURES > 0)); then
  die "$FAILURES validation check(s) failed"
fi

log "Control Tower validation passed"
