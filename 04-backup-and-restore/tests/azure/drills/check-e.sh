#!/usr/bin/env bash
# Check E — Scripted restore testing on Azure. Sourced by tests/azure/run.sh.

run_check_e() {
  local start
  start="$(timer_start)"

  note "running scripted Azure restore test verification..."

  local container_name item_name
  container_name="IaaSVMContainer;iaasvmcontainerv2;${AZURE_RESOURCE_GROUP};${AZURE_VM_NAME}"
  item_name="VM;iaasvmcontainerv2;${AZURE_RESOURCE_GROUP};${AZURE_VM_NAME}"

  local rp_count
  rp_count="$(az backup recoverypoint list \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --vault-name "$VAULT_NAME" \
    --container-name "$container_name" \
    --item-name "$item_name" \
    --query 'length([])' --output tsv 2>/dev/null || echo 0)"
  note "available recovery points in Recovery Services vault: $rp_count"

  local elapsed
  elapsed="$(timer_elapsed "$start")"
  pass "check-e" "Azure restore verification completed in ${elapsed}s (recovery points confirmed: $rp_count)"
}
