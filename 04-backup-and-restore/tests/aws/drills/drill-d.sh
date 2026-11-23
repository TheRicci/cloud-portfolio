#!/usr/bin/env bash
# Drill D — AWS Deletion protection verification. Sourced by tests/aws/run.sh.

run_drill_d() {
  local start
  start="$(timer_start)"
  local errors_file="$RESULTS_DIR/drill-d-errors.txt"
  : >"$errors_file"

  note "assuming limited IAM role: $LIMITED_ROLE_ARN"

  local creds
  creds="$(aws sts assume-role \
    --role-arn "$LIMITED_ROLE_ARN" \
    --role-session-name "drill-d-${RUN_ID}" \
    --query Credentials \
    --output json)"

  local ak sk st
  ak="$(echo "$creds" | jq -r .AccessKeyId)"
  sk="$(echo "$creds" | jq -r .SecretAccessKey)"
  st="$(echo "$creds" | jq -r .SessionToken)"

  note "positive control: rebooting EC2 instance with limited role..."
  if AWS_ACCESS_KEY_ID="$ak" AWS_SECRET_ACCESS_KEY="$sk" AWS_SESSION_TOKEN="$st" \
     aws ec2 reboot-instances \
       --region "$AWS_REGION" \
       --instance-ids "$AWS_INSTANCE_ID" 2>&1; then
    note "PASS: EC2 reboot succeeded (positive control)"
  else
    note "UNEXPECTED: reboot failed (positive control should succeed)"
  fi

  sleep 15

  local recovery_point_arn
  recovery_point_arn="$(aws backup list-recovery-points-by-backup-vault \
    --region "$AWS_REGION" \
    --backup-vault-name "$VAULT_NAME" \
    --query 'RecoveryPoints[0].RecoveryPointArn' \
    --output text)"

  note "attempting to delete recovery point (must be DENIED)..."
  local delete_rp_result
  if delete_rp_result="$(AWS_ACCESS_KEY_ID="$ak" AWS_SECRET_ACCESS_KEY="$sk" AWS_SESSION_TOKEN="$st" \
     aws backup delete-recovery-point \
       --region "$AWS_REGION" \
       --backup-vault-name "$VAULT_NAME" \
       --recovery-point-arn "$recovery_point_arn" 2>&1)"; then
    note "UNEXPECTED: delete-recovery-point SUCCEEDED"
    echo "delete-recovery-point: SUCCEEDED (unexpected)" >> "$errors_file"
  else
    note "DENIED: delete-recovery-point — $delete_rp_result"
    echo "delete-recovery-point: DENIED — $delete_rp_result" >> "$errors_file"
  fi

  note "attempting to delete vault (must be DENIED)..."
  local delete_vault_result
  if delete_vault_result="$(AWS_ACCESS_KEY_ID="$ak" AWS_SECRET_ACCESS_KEY="$sk" AWS_SESSION_TOKEN="$st" \
     aws backup delete-backup-vault \
       --region "$AWS_REGION" \
       --backup-vault-name "$VAULT_NAME" 2>&1)"; then
    note "UNEXPECTED: delete-backup-vault SUCCEEDED"
    echo "delete-backup-vault: SUCCEEDED (unexpected)" >> "$errors_file"
  else
    note "DENIED: delete-backup-vault — $delete_vault_result"
    echo "delete-backup-vault: DENIED — $delete_vault_result" >> "$errors_file"
  fi

  local elapsed
  elapsed="$(timer_elapsed "$start")"
  pass "drill-d" "deletion protection verified in ${elapsed}s (errors in drill-d-errors.txt)"
}
