#!/usr/bin/env bash
# Destroys what run-session.sh created, then audits for leftovers.
# Safe to run twice. Usage: teardown.sh aws|azure
set -uo pipefail
CLOUD="${1:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=lib.sh
. "$HERE/lib.sh"

[[ "$CLOUD" == aws || "$CLOUD" == azure ]] || die "usage: $0 aws|azure"
SESSION_ENV="$ROOT/tests/.session/$CLOUD.env"
[[ -f "$SESSION_ENV" ]] || die "no session file for $CLOUD on this machine; destroy from the console and run audit-leftovers.sh"

# shellcheck source=/dev/null
. "$SESSION_ENV"
if [[ "$CLOUD" == azure ]]; then
  ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
  export ARM_SUBSCRIPTION_ID
fi

terraform -chdir="$ROOT/$CLOUD" destroy -auto-approve -input=false || log "terraform destroy reported errors"
# shellcheck disable=SC2154  # TF_VAR_region comes from the sourced session file
REGION="${TF_VAR_region:?}" "$HERE/audit-leftovers.sh" "$CLOUD"
