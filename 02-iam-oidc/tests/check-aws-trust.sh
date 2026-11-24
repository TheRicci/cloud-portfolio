#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <assume-role-policy.json>" >&2
  exit 64
fi

policy_file="$1"
audience=$(jq -r '.Statement[] | .Condition.StringEquals["token.actions.githubusercontent.com:aud"] // empty' "$policy_file")
subject=$(jq -r '.Statement[] | .Condition.StringEquals["token.actions.githubusercontent.com:sub"] // empty' "$policy_file")

[[ "$audience" == "sts.amazonaws.com" ]] || { echo "missing exact STS audience" >&2; exit 1; }
[[ "$subject" == repo:* ]] || { echo "missing GitHub OIDC subject" >&2; exit 1; }
[[ "$subject" != *"*"* ]] || { echo "wildcard subjects are forbidden" >&2; exit 1; }

echo "AWS trust policy has an exact audience and subject."
