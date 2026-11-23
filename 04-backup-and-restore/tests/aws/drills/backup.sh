#!/usr/bin/env bash
# Takes AWS Backup and pg_dump. Sourced by tests/aws/run.sh.

run_backup() {
  local start
  start="$(timer_start)"

  note "waiting for VM and writer..."
  local attempts=0
  while (( attempts < 60 )); do
    local count
    count="$(get_row_count 2>/dev/null || echo 0)"
    count="$(echo "$count" | tr -d '[:space:]')"
    if [[ -n "$count" ]] && (( count > 0 )); then
      note "writer is running, row count=$count"
      break
    fi
    if (( attempts % 3 == 0 )); then
      note "  polling VM & writer... attempt $(( attempts + 1 ))/60 (current rows: ${count:-0})"
    fi
    sleep 10
    attempts=$(( attempts + 1 ))
  done
  if (( attempts >= 60 )); then
    fail "backup" "VM or writer not ready after 600s"
    return 1
  fi

  local count1 count2
  count1="$(get_row_count)"
  sleep 5
  count2="$(get_row_count)"
  if (( count2 <= count1 )); then
    fail "backup" "row count not rising: $count1 -> $count2"
    return 1
  fi
  note "rows rising: $count1 -> $count2"

  seed_files

  note "triggering AWS Backup on-demand job..."
  local account_id instance_arn backup_job_id
  account_id="$(aws sts get-caller-identity --query Account --output text)"
  instance_arn="arn:aws:ec2:${AWS_REGION}:${account_id}:instance/${AWS_INSTANCE_ID}"

  backup_job_id="$(aws backup start-backup-job \
    --region "$AWS_REGION" \
    --backup-vault-name "$VAULT_NAME" \
    --resource-arn "$instance_arn" \
    --iam-role-arn "$BACKUP_ROLE_ARN" \
    --query BackupJobId --output text)"
  note "AWS Backup job started: $backup_job_id"

  wait_backup_aws "$backup_job_id" 1200 || {
    fail "backup" "AWS Backup job $backup_job_id failed"
    return 1
  }
  note "AWS Backup job completed"

  note "running pg_dump on VM..."
  local dump_name="dump-${RUN_ID}.sql"
  remote "export PATH=\$PATH:/usr/local/bin; sudo -u postgres pg_dump backuplab > /tmp/$dump_name && aws s3 cp /tmp/$dump_name s3://$BUCKET_NAME/dumps/$dump_name" || {
    fail "backup" "pg_dump or S3 upload failed"
    return 1
  }
  note "pg_dump uploaded to s3://$BUCKET_NAME/dumps/$dump_name"

  local elapsed
  elapsed="$(timer_elapsed "$start")"
  pass "backup" "all AWS backups completed in ${elapsed}s"
}
