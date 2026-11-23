#!/usr/bin/env bash
# Runs the full AWS backup-lab drill session.
# Automatically detects outputs from Terraform in 04-backup-and-restore/aws.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWS_TF_DIR="$ROOT/aws"

echo "=== Auto-detecting AWS configuration from Terraform ==="
if [[ ! -d "$AWS_TF_DIR/.terraform" && ! -f "$AWS_TF_DIR/terraform.tfstate" ]]; then
  echo "ERROR: Terraform state not found in $AWS_TF_DIR." >&2
  echo "Please deploy infrastructure first: cd aws && terraform apply" >&2
  exit 1
fi

AWS_INSTANCE_ID="${AWS_INSTANCE_ID:-$(terraform -chdir="$AWS_TF_DIR" output -raw instance_id 2>/dev/null || true)}"
AWS_REGION="${AWS_REGION:-$(terraform -chdir="$AWS_TF_DIR" output -raw region 2>/dev/null || echo "us-east-1")}"
BUCKET_NAME="${BUCKET_NAME:-$(terraform -chdir="$AWS_TF_DIR" output -raw bucket_name 2>/dev/null || true)}"
VAULT_NAME="${VAULT_NAME:-$(terraform -chdir="$AWS_TF_DIR" output -raw backup_vault_name 2>/dev/null || true)}"
BACKUP_ROLE_ARN="${BACKUP_ROLE_ARN:-$(terraform -chdir="$AWS_TF_DIR" output -raw backup_service_role_arn 2>/dev/null || true)}"
LIMITED_ROLE_ARN="${LIMITED_ROLE_ARN:-$(terraform -chdir="$AWS_TF_DIR" output -raw limited_role_arn 2>/dev/null || true)}"

if [[ -z "$AWS_INSTANCE_ID" || -z "$BUCKET_NAME" || -z "$VAULT_NAME" || -z "$BACKUP_ROLE_ARN" || -z "$LIMITED_ROLE_ARN" ]]; then
  echo "ERROR: Could not read all required Terraform outputs from $AWS_TF_DIR." >&2
  echo "Ensure 'terraform apply' succeeded in the aws directory." >&2
  exit 1
fi

echo "  Instance ID:      $AWS_INSTANCE_ID"
echo "  Region:           $AWS_REGION"
echo "  S3 Bucket:        $BUCKET_NAME"
echo "  Backup Vault:     $VAULT_NAME"
echo "  Backup Role ARN:  $BACKUP_ROLE_ARN"
echo "  Limited Role ARN: $LIMITED_ROLE_ARN"
echo ""

# Tool prerequisites check
for cmd in jq openssl sha256sum aws; do
  command -v "$cmd" >/dev/null || { echo "missing required tool: $cmd" >&2; exit 2; }
done

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-aws"
RESULTS_DIR="$ROOT/tests/results/$RUN_ID"
LOG="$RESULTS_DIR/session-log.md"
mkdir -p "$RESULTS_DIR"
: >"$LOG"

declare -A STATUS DETAIL
SESSION_START="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
LAST_ROW_ID="" LAST_ROW_AT=""

export AWS_REGION AWS_INSTANCE_ID BUCKET_NAME VAULT_NAME RESULTS_DIR LOG RUN_ID SESSION_START
export BACKUP_ROLE_ARN LIMITED_ROLE_ARN

# shellcheck source=lib.sh
source "$ROOT/tests/aws/lib.sh"

note "=== Starting AWS Backup Lab Session ==="
note "run_id=$RUN_ID"

cleanup() {
  local exit_code=$?
  note "=== Auto-Teardown (exit trap) ==="
  bash "$ROOT/tests/aws/teardown.sh" || note "teardown reported warnings"
  write_results_json
  note "=== Session Finished (exit code: $exit_code) ==="
}
trap cleanup EXIT

note "--- Step 1: Preflight ---"
# shellcheck source=drills/preflight.sh
source "$ROOT/tests/aws/drills/preflight.sh"
run_preflight

note "--- Step 2: Backup ---"
# shellcheck source=drills/backup.sh
source "$ROOT/tests/aws/drills/backup.sh"
run_backup

note "--- Step 3: Drill A — VM Loss & Restore ---"
# shellcheck source=drills/drill-a.sh
source "$ROOT/tests/aws/drills/drill-a.sh"
run_drill_a

note "--- Step 4: Drill B — Data Loss & Logical Dump Restore ---"
# shellcheck source=drills/drill-b.sh
source "$ROOT/tests/aws/drills/drill-b.sh"
run_drill_b

note "--- Step 5: Drill C — S3 Object Corruption & Version Recovery ---"
# shellcheck source=drills/drill-c.sh
source "$ROOT/tests/aws/drills/drill-c.sh"
run_drill_c

note "--- Step 6: Drill D — IAM Deletion Protection ---"
# shellcheck source=drills/drill-d.sh
source "$ROOT/tests/aws/drills/drill-d.sh"
run_drill_d

note "--- Step 7: Check E — Native/Scripted Restore Testing ---"
# shellcheck source=drills/check-e.sh
source "$ROOT/tests/aws/drills/check-e.sh"
run_check_e

note "=== All AWS Drills Passed Successfully ==="
