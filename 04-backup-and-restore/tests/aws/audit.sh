#!/usr/bin/env bash
# Leftover audit for AWS. Exits non-zero if any resources remain.
set -Euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWS_TF_DIR="$ROOT/aws"
AWS_REGION="${AWS_REGION:-$(terraform -chdir="$AWS_TF_DIR" output -raw region 2>/dev/null || echo "us-east-1")}"

found=0

report() {
  local category="$1" items="$2" cost_estimate="$3"
  if [[ -n "$items" && "$items" != "None" ]]; then
    echo "LEFTOVER [$category]: $items"
    echo "  estimated monthly cost: $cost_estimate"
    found=1
  fi
}

echo "=== AWS Leftover Audit (region=$AWS_REGION) ==="

# EC2 instances
items="$(aws ec2 describe-instances --region "$AWS_REGION" \
  --filters "Name=tag:project,Values=backup-lab" "Name=instance-state-name,Values=running,stopped,pending" \
  --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || true)"
report "EC2 instances" "$items" "~\$8/mo per t3.micro"

# EBS volumes
items="$(aws ec2 describe-volumes --region "$AWS_REGION" \
  --filters "Name=tag:project,Values=backup-lab" \
  --query 'Volumes[].VolumeId' --output text 2>/dev/null || true)"
report "EBS volumes" "$items" "~\$1/mo per 8GB gp3"

# Snapshots
items="$(aws ec2 describe-snapshots --region "$AWS_REGION" \
  --owner-ids self \
  --filters "Name=tag:project,Values=backup-lab" \
  --query 'Snapshots[].SnapshotId' --output text 2>/dev/null || true)"
report "EBS snapshots" "$items" "~\$0.40/mo per 8GB"

# Backup recovery points
vault="${VAULT_NAME:-$(terraform -chdir="$AWS_TF_DIR" output -raw backup_vault_name 2>/dev/null || echo "backup-lab-vault")}"
items="$(aws backup list-recovery-points-by-backup-vault --region "$AWS_REGION" \
  --backup-vault-name "$vault" \
  --query 'RecoveryPoints[].RecoveryPointArn' --output text 2>/dev/null || true)"
report "Backup recovery points" "$items" "~\$0.50/mo per 10GB"

# Backup vaults
items="$(aws backup list-backup-vaults --region "$AWS_REGION" \
  --query "BackupVaultList[?contains(BackupVaultName,'backup-lab')].BackupVaultName" --output text 2>/dev/null || true)"
report "Backup vaults" "$items" "\$0 (vault itself is free)"

# S3 buckets
items="$(aws s3api list-buckets \
  --query "Buckets[?contains(Name,'backup-lab')].Name" --output text 2>/dev/null || true)"
report "S3 buckets" "$items" "~\$0.02/mo per GB"

# Elastic IPs
items="$(aws ec2 describe-addresses --region "$AWS_REGION" \
  --filters "Name=tag:project,Values=backup-lab" \
  --query 'Addresses[].AllocationId' --output text 2>/dev/null || true)"
report "Elastic IPs" "$items" "~\$3.65/mo each"

echo ""
if (( found == 0 )); then
  echo "AUDIT CLEAN — no AWS leftovers found."
  exit 0
else
  echo "AUDIT FAILED — AWS leftovers found above."
  exit 1
fi
