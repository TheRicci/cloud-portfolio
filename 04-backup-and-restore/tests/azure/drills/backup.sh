#!/usr/bin/env bash
# Takes Azure Recovery Services backup and pg_dump. Sourced by tests/azure/run.sh.

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

  note "triggering Azure Backup (Recovery Services) on-demand job..."
  local container_name item_name
  container_name="IaaSVMContainer;iaasvmcontainerv2;${AZURE_RESOURCE_GROUP};${AZURE_VM_NAME}"
  item_name="VM;iaasvmcontainerv2;${AZURE_RESOURCE_GROUP};${AZURE_VM_NAME}"

  az backup protection backup-now \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --vault-name "$VAULT_NAME" \
    --container-name "$container_name" \
    --item-name "$item_name" \
    --output none

  local job_name
  job_name="$(az backup job list \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --vault-name "$VAULT_NAME" \
    --query '[0].name' --output tsv)"
  note "Azure Backup job started: $job_name"

  wait_backup_azure "$job_name" 1200 || {
    fail "backup" "Azure Backup job $job_name failed"
    return 1
  }
  note "Azure Backup job completed"

  note "running pg_dump on VM..."
  local dump_name="dump-${RUN_ID}.sql"
  remote "sudo -u postgres pg_dump backuplab > /tmp/$dump_name && az storage blob upload --account-name $STORAGE_ACCOUNT --container-name dumps --name $dump_name --file /tmp/$dump_name --auth-mode login --output none" || {
    fail "backup" "pg_dump or Azure blob upload failed"
    return 1
  }
  note "pg_dump uploaded to dumps container: $dump_name"

  local elapsed
  elapsed="$(timer_elapsed "$start")"
  pass "backup" "all Azure backups completed in ${elapsed}s"
}
