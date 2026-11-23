#!/usr/bin/env bash
# Leftover audit for Azure. Exits non-zero if any billable resources remain.
set -Euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AZURE_TF_DIR="$ROOT/azure"
AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-$(terraform -chdir="$AZURE_TF_DIR" output -raw resource_group_name 2>/dev/null || echo "rg-backup-lab")}"

found=0

report() {
  local category="$1" items="$2" cost_estimate="$3"
  if [[ -n "$items" && "$items" != "None" ]]; then
    echo "LEFTOVER [$category]: $items"
    echo "  estimated monthly cost: $cost_estimate"
    found=1
  fi
}

echo "=== Azure Leftover Audit (rg=$AZURE_RESOURCE_GROUP) ==="

if ! az group show --name "$AZURE_RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Resource group $AZURE_RESOURCE_GROUP does not exist — clean."
  exit 0
fi

# VMs
items="$(az vm list --resource-group "$AZURE_RESOURCE_GROUP" \
  --query '[].name' --output tsv 2>/dev/null || true)"
report "VMs" "$items" "~\$7/mo per B2ats_v2"

# Managed Disks
items="$(az disk list --resource-group "$AZURE_RESOURCE_GROUP" \
  --query '[].name' --output tsv 2>/dev/null || true)"
report "Managed disks" "$items" "~\$1/mo per disk"

# Recovery Services Vaults
items="$(az backup vault list --resource-group "$AZURE_RESOURCE_GROUP" \
  --query '[].name' --output tsv 2>/dev/null || true)"
report "Recovery Services vaults" "$items" "~\$5/mo (protected instance fee)"

# Storage Accounts
items="$(az storage account list --resource-group "$AZURE_RESOURCE_GROUP" \
  --query '[].name' --output tsv 2>/dev/null || true)"
report "Storage accounts" "$items" "~\$0.02/mo per GB"

# Public IPs
items="$(az network public-ip list --resource-group "$AZURE_RESOURCE_GROUP" \
  --query '[].name' --output tsv 2>/dev/null || true)"
report "Public IPs" "$items" "~\$3.65/mo each"

# Network Interfaces
items="$(az network nic list --resource-group "$AZURE_RESOURCE_GROUP" \
  --query '[].name' --output tsv 2>/dev/null || true)"
report "Network interfaces" "$items" "\$0 (NIC is free)"

echo ""
if (( found == 0 )); then
  echo "AUDIT CLEAN — no Azure billable leftovers found."
  exit 0
else
  echo "AUDIT FAILED — Azure leftovers found above."
  exit 1
fi
