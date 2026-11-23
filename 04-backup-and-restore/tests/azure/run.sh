#!/usr/bin/env bash
# Runs the full Azure backup-lab drill session.
# Automatically detects outputs from Terraform in 04-backup-and-restore/azure.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AZURE_TF_DIR="$ROOT/azure"

echo "=== Auto-detecting Azure configuration from Terraform ==="
if [[ ! -d "$AZURE_TF_DIR/.terraform" && ! -f "$AZURE_TF_DIR/terraform.tfstate" ]]; then
  echo "ERROR: Terraform state not found in $AZURE_TF_DIR." >&2
  echo "Please deploy infrastructure first: cd azure && terraform apply" >&2
  exit 1
fi

AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-$(terraform -chdir="$AZURE_TF_DIR" output -raw resource_group_name 2>/dev/null || true)}"
AZURE_VM_NAME="${AZURE_VM_NAME:-$(terraform -chdir="$AZURE_TF_DIR" output -raw vm_name 2>/dev/null || true)}"
AZURE_VM_ID="${AZURE_VM_ID:-$(terraform -chdir="$AZURE_TF_DIR" output -raw vm_id 2>/dev/null || true)}"
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-$(terraform -chdir="$AZURE_TF_DIR" output -raw storage_account_name 2>/dev/null || true)}"
VAULT_NAME="${VAULT_NAME:-$(terraform -chdir="$AZURE_TF_DIR" output -raw vault_name 2>/dev/null || true)}"
AZURE_LOCATION="${AZURE_LOCATION:-$(terraform -chdir="$AZURE_TF_DIR" output -raw location 2>/dev/null || echo "eastus")}"
AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-$(terraform -chdir="$AZURE_TF_DIR" output -raw subscription_id 2>/dev/null || true)}"

if [[ -z "$AZURE_RESOURCE_GROUP" || -z "$AZURE_VM_NAME" || -z "$STORAGE_ACCOUNT" || -z "$VAULT_NAME" ]]; then
  echo "ERROR: Could not read all required Terraform outputs from $AZURE_TF_DIR." >&2
  echo "Ensure 'terraform apply' succeeded in the azure directory." >&2
  exit 1
fi

echo "  Resource Group:   $AZURE_RESOURCE_GROUP"
echo "  VM Name:          $AZURE_VM_NAME"
echo "  Storage Account:  $STORAGE_ACCOUNT"
echo "  Vault Name:       $VAULT_NAME"
echo "  Location:         $AZURE_LOCATION"
echo "  Subscription ID:  ${AZURE_SUBSCRIPTION_ID:0:4}****${AZURE_SUBSCRIPTION_ID: -4}"
echo ""

# Tool prerequisites check
for cmd in jq openssl sha256sum az; do
  command -v "$cmd" >/dev/null || { echo "missing required tool: $cmd" >&2; exit 2; }
done

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-azure"
RESULTS_DIR="$ROOT/tests/results/$RUN_ID"
LOG="$RESULTS_DIR/session-log.md"
mkdir -p "$RESULTS_DIR"
: >"$LOG"

declare -A STATUS DETAIL
SESSION_START="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
LAST_ROW_ID="" LAST_ROW_AT=""

export AZURE_RESOURCE_GROUP AZURE_VM_NAME AZURE_VM_ID STORAGE_ACCOUNT VAULT_NAME
export AZURE_LOCATION AZURE_SUBSCRIPTION_ID RESULTS_DIR LOG RUN_ID SESSION_START

# shellcheck source=lib.sh
source "$ROOT/tests/azure/lib.sh"

note "=== Starting Azure Backup Lab Session ==="
note "run_id=$RUN_ID"

cleanup() {
  local exit_code=$?
  note "=== Auto-Teardown (exit trap) ==="
  bash "$ROOT/tests/azure/teardown.sh" || note "teardown reported warnings"
  write_results_json
  note "=== Session Finished (exit code: $exit_code) ==="
}
trap cleanup EXIT

note "--- Step 1: Preflight ---"
# shellcheck source=drills/preflight.sh
source "$ROOT/tests/azure/drills/preflight.sh"
run_preflight

note "--- Step 2: Backup ---"
# shellcheck source=drills/backup.sh
source "$ROOT/tests/azure/drills/backup.sh"
run_backup

note "--- Step 3: Drill A — VM Loss & Restore ---"
# shellcheck source=drills/drill-a.sh
source "$ROOT/tests/azure/drills/drill-a.sh"
run_drill_a

note "--- Step 4: Drill B — Data Loss & Logical Dump Restore ---"
# shellcheck source=drills/drill-b.sh
source "$ROOT/tests/azure/drills/drill-b.sh"
run_drill_b

note "--- Step 5: Drill C — Blob Corruption & Version Recovery ---"
# shellcheck source=drills/drill-c.sh
source "$ROOT/tests/azure/drills/drill-c.sh"
run_drill_c

note "--- Step 6: Drill D — RBAC Deletion Protection ---"
# shellcheck source=drills/drill-d.sh
source "$ROOT/tests/azure/drills/drill-d.sh"
run_drill_d

note "--- Step 7: Check E — Native/Scripted Restore Testing ---"
# shellcheck source=drills/check-e.sh
source "$ROOT/tests/azure/drills/check-e.sh"
run_check_e

note "=== All Azure Drills Passed Successfully ==="
