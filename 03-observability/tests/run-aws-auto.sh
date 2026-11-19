#!/usr/bin/env bash
# Reads instance IDs from AWS directly (by tag) and falls back to Terraform
# outputs for region and alarm name. No stale-state issues.
#
# Usage (from the 03-observability directory, in Git Bash):
#   bash tests/run-aws-auto.sh
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_DIR="$SCRIPT_DIR/../aws"

# Region and alarm name: try terraform output, fall back to known defaults.
AWS_REGION="$(terraform -chdir="$AWS_DIR" output -raw region 2>/dev/null || echo "us-east-1")"
AWS_ALARM_NAME="$(terraform -chdir="$AWS_DIR" output -raw cloudwatch_alarm_name 2>/dev/null || echo "portfolio-observability-high-cpu")"

# Instance IDs: query AWS directly by tag — always current, never stale.
echo "Discovering instance IDs from AWS (region: $AWS_REGION) ..."

AWS_INSTANCE_ID="$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters \
    "Name=tag:Name,Values=portfolio-observability-workload" \
    "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)"

AWS_MONITORING_INSTANCE_ID="$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters \
    "Name=tag:Name,Values=portfolio-observability-monitoring" \
    "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)"

if [[ "$AWS_INSTANCE_ID" == "None" || -z "$AWS_INSTANCE_ID" ]]; then
  echo "ERROR: No running workload VM found with tag Name=portfolio-observability-workload" >&2
  exit 1
fi
if [[ "$AWS_MONITORING_INSTANCE_ID" == "None" || -z "$AWS_MONITORING_INSTANCE_ID" ]]; then
  echo "ERROR: No running monitoring VM found with tag Name=portfolio-observability-monitoring" >&2
  exit 1
fi

export AWS_INSTANCE_ID
export AWS_MONITORING_INSTANCE_ID
export AWS_REGION
export AWS_ALARM_NAME

echo "  Workload VM:   $AWS_INSTANCE_ID"
echo "  Monitoring VM: $AWS_MONITORING_INSTANCE_ID"
echo "  Region:        $AWS_REGION"
echo "  Alarm:         $AWS_ALARM_NAME"
echo ""

exec bash "$SCRIPT_DIR/run-aws-session.sh"
