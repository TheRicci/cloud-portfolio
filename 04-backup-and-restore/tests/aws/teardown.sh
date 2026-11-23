#!/usr/bin/env bash
# Tears down all AWS resources created during the lab.
# Safe to run multiple times.
set -Euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWS_TF_DIR="$ROOT/aws"

if [[ -f "$ROOT/tests/aws/lib.sh" ]]; then
  LOG="${LOG:-/dev/stderr}"
  RESULTS_DIR="${RESULTS_DIR:-/tmp}"
  declare -A STATUS DETAIL 2>/dev/null || true
  # shellcheck source=lib.sh
  source "$ROOT/tests/aws/lib.sh"
else
  note() { echo "$@"; }
fi

note "=== Teardown: AWS ==="

AWS_REGION="${AWS_REGION:-$(terraform -chdir="$AWS_TF_DIR" output -raw region 2>/dev/null || echo "us-east-1")}"
VAULT_NAME="${VAULT_NAME:-$(terraform -chdir="$AWS_TF_DIR" output -raw backup_vault_name 2>/dev/null || echo "backup-lab-vault")}"

# 1. Terminate any restored/test EC2 instances created outside Terraform
note "terminating any restored/test instances tagged project=backup-lab..."
instance_ids="$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters "Name=tag:project,Values=backup-lab" "Name=instance-state-name,Values=running,stopped,pending" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text 2>/dev/null || true)"

if [[ -n "$instance_ids" ]]; then
  note "terminating instances: $instance_ids"
  # shellcheck disable=SC2086
  aws ec2 terminate-instances --region "$AWS_REGION" --instance-ids $instance_ids --output text >/dev/null 2>&1 || true
  # shellcheck disable=SC2086
  aws ec2 wait instance-terminated --region "$AWS_REGION" --instance-ids $instance_ids 2>/dev/null || true
fi

# 2. Delete recovery points from the vault (AWS Backup blocks vault deletion if recovery points exist)
note "deleting backup recovery points from vault $VAULT_NAME..."
rps="$(aws backup list-recovery-points-by-backup-vault \
  --region "$AWS_REGION" \
  --backup-vault-name "$VAULT_NAME" \
  --query 'RecoveryPoints[].RecoveryPointArn' \
  --output text 2>/dev/null || true)"

for rp in $rps; do
  note "  deleting recovery point $rp"
  aws backup delete-recovery-point \
    --region "$AWS_REGION" \
    --backup-vault-name "$VAULT_NAME" \
    --recovery-point-arn "$rp" 2>/dev/null || true
done

# 3. Delete unattached EBS volumes tagged project=backup-lab
note "checking for unattached EBS volumes..."
volumes="$(aws ec2 describe-volumes \
  --region "$AWS_REGION" \
  --filters "Name=tag:project,Values=backup-lab" "Name=status,Values=available" \
  --query 'Volumes[].VolumeId' \
  --output text 2>/dev/null || true)"

for vol in $volumes; do
  note "  deleting volume $vol"
  aws ec2 delete-volume --region "$AWS_REGION" --volume-id "$vol" 2>/dev/null || true
done

# 4. Terraform destroy
note "running terraform destroy on AWS infrastructure..."
if [[ -d "$AWS_TF_DIR" ]]; then
  terraform -chdir="$AWS_TF_DIR" destroy -auto-approve 2>&1 | tail -10 || true
fi

note "running audit to confirm complete removal..."
bash "$ROOT/tests/aws/audit.sh" || note "AUDIT FOUND LEFTOVERS"
