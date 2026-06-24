#!/bin/sh
set -eu

status=0

for path in "$@"; do
  case "$path" in
    *.tfstate|*.tfstate.*|*.tfplan|*.plan|*.tfvars|*.tfvars.json|*.pem|*.key|*.p12|*.pfx|*.jks|*.keystore|*.token|credentials|credentials.*|.env|.env.*)
      case "$path" in
        *.tfvars.example|*.tfvars.json.example|.env.example)
          continue
          ;;
      esac
      echo "Refusing sensitive or generated file: $path" >&2
      status=1
      ;;
    docs/evidence/*)
      if test "$path" != "docs/evidence/README.md"; then
        echo "Generated evidence is ignored by default: $path" >&2
        status=1
      fi
      ;;
  esac
done

exit "$status"
