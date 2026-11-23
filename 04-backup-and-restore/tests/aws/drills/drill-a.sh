#!/usr/bin/env bash
# Drill A — AWS VM loss and restore. Sourced by tests/aws/run.sh.

run_drill_a() {
  local start
  start="$(timer_start)"

  record_last_row

  note "terminating EC2 VM..."
  aws ec2 terminate-instances \
    --region "$AWS_REGION" \
    --instance-ids "$AWS_INSTANCE_ID" \
    --output text >/dev/null

  note "waiting for instance termination..."
  aws ec2 wait instance-terminated \
    --region "$AWS_REGION" \
    --instance-ids "$AWS_INSTANCE_ID" 2>/dev/null || true
  note "EC2 VM terminated"

  local recovery_point_arn
  recovery_point_arn="$(aws backup list-recovery-points-by-backup-vault \
    --region "$AWS_REGION" \
    --backup-vault-name "$VAULT_NAME" \
    --query 'RecoveryPoints | sort_by(@, &CreationDate) | [-1].RecoveryPointArn' \
    --output text)"
  note "restoring from recovery point: $recovery_point_arn"

  local sg_id subnet_id profile_name orig_metadata restore_metadata restore_job_id
  sg_id="$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters Name=tag:project,Values=backup-lab --query 'SecurityGroups[0].GroupId' --output text)"
  subnet_id="$(aws ec2 describe-subnets --region "$AWS_REGION" --filters Name=tag:project,Values=backup-lab --query 'Subnets[0].SubnetId' --output text)"
  profile_name="$(aws iam list-instance-profiles --query "InstanceProfiles[?contains(InstanceProfileName,'backup-lab')].InstanceProfileName | [0]" --output text)"

  orig_metadata="$(aws backup get-recovery-point-restore-metadata \
    --region "$AWS_REGION" \
    --backup-vault-name "$VAULT_NAME" \
    --recovery-point-arn "$recovery_point_arn" \
    --query 'RestoreMetadata' --output json 2>/dev/null || echo '{}')"

  restore_metadata="$(echo "$orig_metadata" | jq -c \
    --arg sg "[\"$sg_id\"]" \
    --arg subnet "$subnet_id" \
    --arg profile_name "$profile_name" \
    'del(.NetworkInterfaces, .IamInstanceProfileArn) |
     .SubnetId = $subnet |
     .SecurityGroupIds = $sg |
     .IamInstanceProfileName = $profile_name |
     .InstanceType = (.InstanceType // "t3.micro")')"

  restore_job_id="$(aws backup start-restore-job \
    --region "$AWS_REGION" \
    --recovery-point-arn "$recovery_point_arn" \
    --iam-role-arn "$BACKUP_ROLE_ARN" \
    --metadata "$restore_metadata" \
    --query RestoreJobId --output text)"
  note "restore job started: $restore_job_id"

  wait_restore_aws "$restore_job_id" 900 || {
    fail "drill-a" "AWS restore job $restore_job_id failed"
    return 1
  }

  local new_instance_id
  new_instance_id="$(aws backup describe-restore-job \
    --region "$AWS_REGION" \
    --restore-job-id "$restore_job_id" \
    --query CreatedResourceArn --output text | grep -oE 'i-[a-f0-9]+')"
  note "restored instance: $new_instance_id"

  aws ec2 create-tags \
    --region "$AWS_REGION" \
    --resources "$new_instance_id" \
    --tags Key=project,Value=backup-lab Key=session_id,Value="$RUN_ID" Key=Name,Value=backup-lab-restored

  AWS_INSTANCE_ID="$new_instance_id"
  export AWS_INSTANCE_ID

  note "waiting for restored VM to register with SSM..."
  local wait_attempts=0
  while (( wait_attempts < 60 )); do
    if aws ssm describe-instance-information \
      --region "$AWS_REGION" \
      --filters "Key=InstanceIds,Values=$AWS_INSTANCE_ID" \
      --query 'length(InstanceInformationList)' --output text 2>/dev/null | grep -q '^[1-9]'; then
      break
    fi
    sleep 10
    wait_attempts=$(( wait_attempts + 1 ))
  done

  note "verifying restored Postgres & dataset..."
  local pg_status
  pg_status="$(remote "systemctl is-active postgresql 2>/dev/null || echo 'inactive'")"
  pg_status="$(echo "$pg_status" | tr -d '[:space:]')"
  if [[ "$pg_status" == *"active"* ]]; then
    note "Postgres is running after restore"
  else
    note "Postgres restarting..."
    remote "sudo systemctl start postgresql" || true
    sleep 5
  fi

  local restored_count
  restored_count="$(get_row_count)"
  note "restored row count: $restored_count (pre-crash last row: $LAST_ROW_ID)"

  if verify_rows; then
    local data_loss=0
    if [[ -n "$LAST_ROW_ID" ]] && [[ -n "$restored_count" ]]; then
      data_loss=$(( LAST_ROW_ID - restored_count ))
      if (( data_loss < 0 )); then data_loss=0; fi
    fi

    local elapsed
    elapsed="$(timer_elapsed "$start")"
    pass "drill-a" "restored and verified. RTO=${elapsed}s, data_loss=${data_loss} rows"
  else
    local elapsed
    elapsed="$(timer_elapsed "$start")"
    fail "drill-a" "checksum verification failed after ${elapsed}s"
  fi
}
