#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 077

usage() {
  cat <<'USAGE'
Usage: assume-role.sh --role-arn ARN [options] [-- command [args...]]

Assume an exact IAM role using the caller's current temporary identity, then run
a command with the returned temporary credentials. Credentials are never printed.

Options:
  --role-arn ARN          Exact target IAM role ARN (required)
  --session-name NAME     STS session name (default: landing-zone-cli-<UTC epoch>)
  --duration SECONDS      Session duration, 900-43200 (default: 3600)
  --mfa-serial ARN        MFA device ARN; token is prompted without echo
  --profile NAME          Source AWS CLI profile
  --region REGION         AWS CLI Region
  -h, --help              Show help

With no command, the script runs sts get-caller-identity and prints only the
assumed identity metadata. It does not write credentials to disk or shell output.
USAGE
}

role_arn=""
session_name="landing-zone-cli-$(date -u +%s)"
duration=3600
mfa_serial=""
profile="${AWS_PROFILE:-}"
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
command_args=()

while (($# > 0)); do
  case "$1" in
    --role-arn)
      (($# >= 2)) || { echo "ERROR: --role-arn requires a value" >&2; exit 2; }
      role_arn=$2
      shift 2
      ;;
    --session-name)
      (($# >= 2)) || { echo "ERROR: --session-name requires a value" >&2; exit 2; }
      session_name=$2
      shift 2
      ;;
    --duration)
      (($# >= 2)) || { echo "ERROR: --duration requires a value" >&2; exit 2; }
      duration=$2
      shift 2
      ;;
    --mfa-serial)
      (($# >= 2)) || { echo "ERROR: --mfa-serial requires a value" >&2; exit 2; }
      mfa_serial=$2
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
    --)
      shift
      command_args=("$@")
      break
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

command -v aws >/dev/null 2>&1 || { echo "ERROR: AWS CLI is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required" >&2; exit 1; }

[[ -n "$role_arn" ]] || { echo "ERROR: --role-arn is required" >&2; exit 2; }
[[ "$role_arn" =~ ^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_/-]+$ ]] || {
  echo "ERROR: --role-arn must be an exact IAM role ARN without wildcards" >&2
  exit 2
}
[[ "$session_name" =~ ^[A-Za-z0-9+=,.@_-]{2,64}$ ]] || {
  echo "ERROR: session name must be 2-64 valid STS session-name characters" >&2
  exit 2
}
[[ "$duration" =~ ^[0-9]+$ ]] && ((duration >= 900 && duration <= 43200)) || {
  echo "ERROR: duration must be 900-43200 seconds and cannot exceed the role's configured maximum" >&2
  exit 2
}
if [[ -n "$mfa_serial" && ! "$mfa_serial" =~ ^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:mfa/[A-Za-z0-9+=,.@_/-]+$ ]]; then
  echo "ERROR: --mfa-serial must be an exact IAM MFA device ARN" >&2
  exit 2
fi

source_args=()
[[ -z "$profile" ]] || source_args+=(--profile "$profile")
[[ -z "$region" ]] || source_args+=(--region "$region")

assume_args=(
  sts assume-role
  --role-arn "$role_arn"
  --role-session-name "$session_name"
  --duration-seconds "$duration"
  --query Credentials
  --output json
  --no-cli-pager
)

mfa_token=""
if [[ -n "$mfa_serial" ]]; then
  read -r -s -p "MFA token: " mfa_token
  printf '\n' >&2
  [[ "$mfa_token" =~ ^[0-9]{6,8}$ ]] || { echo "ERROR: MFA token must contain 6-8 digits" >&2; exit 2; }
  assume_args+=(--serial-number "$mfa_serial" --token-code "$mfa_token")
fi

credentials=$(AWS_PAGER="" aws "${source_args[@]}" "${assume_args[@]}")
mfa_token=""

access_key=$(jq -er '.AccessKeyId' <<<"$credentials")
secret_key=$(jq -er '.SecretAccessKey' <<<"$credentials")
session_token=$(jq -er '.SessionToken' <<<"$credentials")

credentials=""
export AWS_ACCESS_KEY_ID="$access_key"
export AWS_SECRET_ACCESS_KEY="$secret_key"
export AWS_SESSION_TOKEN="$session_token"
unset AWS_PROFILE AWS_DEFAULT_PROFILE
[[ -z "$region" ]] || export AWS_REGION="$region" AWS_DEFAULT_REGION="$region"

access_key=""
secret_key=""
session_token=""

if ((${#command_args[@]} == 0)); then
  exec aws sts get-caller-identity --output json --no-cli-pager
fi

exec "${command_args[@]}"
