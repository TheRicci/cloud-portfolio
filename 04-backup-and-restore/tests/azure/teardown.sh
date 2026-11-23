#!/usr/bin/env bash
# Tears down all Azure resources created during the lab.
# Safe to run multiple times. Handles soft-delete purge.
set -Euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AZURE_TF_DIR="$ROOT/azure"

if [[ -f "$ROOT/tests/azure/lib.sh" ]]; then
  LOG="${LOG:-/dev/stderr}"
  RESULTS_DIR="${RESULTS_DIR:-/tmp}"
  declare -A STATUS DETAIL 2>/dev/null || true
  # shellcheck source=lib.sh
  source "$ROOT/tests/azure/lib.sh"
else
  note() { echo "$@"; }
fi

note "=== Teardown: Azure ==="

AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-$(terraform -chdir="$AZURE_TF_DIR" output -raw resource_group_name 2>/dev/null || echo "rg-backup-lab")}"
VAULT_NAME="${VAULT_NAME:-$(terraform -chdir="$AZURE_TF_DIR" output -raw vault_name 2>/dev/null || echo "rsv-backup-lab")}"

# 1. Delete any restored/test VMs
note "deleting any restored or test VMs in $AZURE_RESOURCE_GROUP..."
vms="$(az vm list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --query "[?tags.project=='backup-lab'].name" \
  --output tsv 2>/dev/null || true)"

for vm in $vms; do
  note "  deleting VM $vm"
  az vm delete --yes --resource-group "$AZURE_RESOURCE_GROUP" --name "$vm" --output none 2>/dev/null || true
done

# 2. Delete unattached managed disks
note "checking for unattached managed disks..."
disks="$(az disk list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --query "[?managedBy==null].name" \
  --output tsv 2>/dev/null || true)"

for disk in $disks; do
  note "  deleting disk $disk"
  az disk delete --yes --resource-group "$AZURE_RESOURCE_GROUP" --name "$disk" --output none 2>/dev/null || true
done

# 3. Soft-delete purge sequence for Recovery Services Vault:
# Azure "Secure by Default" retains deleted backup items in soft-deleted state.
# Vault deletion is blocked unless we undelete then stop-and-delete.
note "cleaning up backup items in vault $VAULT_NAME..."

# Step 3a: Undelete any items currently in soft-delete state
soft_deleted="$(az backup item list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --vault-name "$VAULT_NAME" \
  --query "[?properties.isScheduledForDeferredDelete==true || properties.protectionState=='SoftDeleted'].{name: name, container: properties.containerName}" \
  --output json 2>/dev/null || echo '[]')"

if [[ "$(echo "$soft_deleted" | jq length 2>/dev/null || echo 0)" -gt 0 ]]; then
  note "  undeleting soft-deleted backup items..."
  echo "$soft_deleted" | jq -r '.[].name' | while read -r item_name; do
    container="$(echo "$soft_deleted" | jq -r --arg n "$item_name" '.[] | select(.name==$n) | .container')"
    note "  undeleting $item_name"
    az backup protection undelete \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --vault-name "$VAULT_NAME" \
      --container-name "$container" \
      --item-name "$item_name" \
      --backup-management-type AzureIaasVM \
      --workload-type VM \
      --output none 2>/dev/null || true
  done
fi

# Step 3b: Disable protection and force delete backup data
items="$(az backup item list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --vault-name "$VAULT_NAME" \
  --query "[].{name: name, container: properties.containerName}" \
  --output json 2>/dev/null || echo '[]')"

if [[ "$(echo "$items" | jq length 2>/dev/null || echo 0)" -gt 0 ]]; then
  echo "$items" | jq -r '.[].name' | while read -r item_name; do
    container="$(echo "$items" | jq -r --arg n "$item_name" '.[] | select(.name==$n) | .container')"
    note "  stopping protection and deleting data: $item_name"
    az backup protection disable \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --vault-name "$VAULT_NAME" \
      --container-name "$container" \
      --item-name "$item_name" \
      --backup-management-type AzureIaasVM \
      --workload-type VM \
      --delete-backup-data true \
      --yes \
      --output none 2>/dev/null || true
  done
fi

# 4. Delete unattached NICs
note "checking for unattached network interfaces..."
nics="$(az network nic list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --query "[?virtualMachine==null].name" \
  --output tsv 2>/dev/null || true)"

for nic in $nics; do
  note "  deleting NIC $nic"
  az network nic delete --resource-group "$AZURE_RESOURCE_GROUP" --name "$nic" --output none 2>/dev/null || true
done

# 5. Terraform destroy
note "running terraform destroy on Azure infrastructure..."
if [[ -d "$AZURE_TF_DIR" ]]; then
  terraform -chdir="$AZURE_TF_DIR" destroy -auto-approve 2>&1 | tail -10 || true
fi

note "running audit to confirm complete removal..."
bash "$ROOT/tests/azure/audit.sh" || note "AUDIT FOUND LEFTOVERS"
