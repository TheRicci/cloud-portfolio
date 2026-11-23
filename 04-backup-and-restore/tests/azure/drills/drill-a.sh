#!/usr/bin/env bash
# Drill A — Azure VM loss and restore. Sourced by tests/azure/run.sh.

run_drill_a() {
  local start
  start="$(timer_start)"

  record_last_row

  note "deleting Azure VM..."
  az vm delete --yes \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$AZURE_VM_NAME" \
    --output none
  note "VM deleted"

  # Delete data disk
  az disk delete --yes \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "disk-${AZURE_VM_NAME##vm-}-data" \
    --output none 2>/dev/null || true

  local container_name item_name
  container_name="IaaSVMContainer;iaasvmcontainerv2;${AZURE_RESOURCE_GROUP};${AZURE_VM_NAME}"
  item_name="VM;iaasvmcontainerv2;${AZURE_RESOURCE_GROUP};${AZURE_VM_NAME}"

  local rp_name
  rp_name="$(az backup recoverypoint list \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --vault-name "$VAULT_NAME" \
    --container-name "$container_name" \
    --item-name "$item_name" \
    --query '[0].name' --output tsv)"
  note "restoring from recovery point: $rp_name"

  az backup restore restore-disks \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --vault-name "$VAULT_NAME" \
    --container-name "$container_name" \
    --item-name "$item_name" \
    --rp-name "$rp_name" \
    --storage-account "$STORAGE_ACCOUNT" \
    --target-resource-group "$AZURE_RESOURCE_GROUP" \
    --output none

  local job_name
  job_name="$(az backup job list \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --vault-name "$VAULT_NAME" \
    --query '[0].name' --output tsv)"

  wait_backup_azure "$job_name" 900 || {
    fail "drill-a" "Azure restore job failed"
    return 1
  }

  note "recreating VM from restored disks..."
  local restored_os_disk
  restored_os_disk="$(az disk list \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --query "sort_by([?managedBy==null], &timeCreated) | [-1].name" \
    --output tsv)"
  note "restored OS disk: $restored_os_disk"

  local restored_vm="vm-${AZURE_VM_NAME##vm-}-restored"
  az network nic create \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "nic-restored" \
    --subnet "snet-vm" \
    --vnet-name "vnet-backup-lab" \
    --network-security-group "nsg-backup-lab-vm" \
    --output none

  az vm create \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$restored_vm" \
    --attach-os-disk "$restored_os_disk" \
    --os-type Linux \
    --nics "nic-restored" \
    --size "Standard_B2ats_v2" \
    --tags project=backup-lab session_id="$RUN_ID" \
    --output none 2>/dev/null || true

  AZURE_VM_NAME="$restored_vm"
  export AZURE_VM_NAME
  note "restored VM created: $AZURE_VM_NAME"

  sleep 30

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
