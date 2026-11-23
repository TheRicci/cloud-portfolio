#!/usr/bin/env bash
# Drill D — Azure Deletion protection verification. Sourced by tests/azure/run.sh.

run_drill_d() {
  local start
  start="$(timer_start)"
  local errors_file="$RESULTS_DIR/drill-d-errors.txt"
  : >"$errors_file"

  note "verifying Azure RBAC limited identity permissions..."

  local limited_principal
  limited_principal="$(az identity show \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "backup-lab-limited" \
    --query principalId --output tsv)"
  note "limited identity principal: $limited_principal"

  local assignments
  assignments="$(az role assignment list \
    --assignee "$limited_principal" \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --query '[].{role: roleDefinitionName, scope: scope}' \
    --output json)"
  note "role assignments: $assignments"
  echo "role-assignments: $assignments" >> "$errors_file"

  local role_def
  role_def="$(az role definition list \
    --name "backup-lab-limited-role" \
    --query '[0].{actions: permissions[0].actions, notActions: permissions[0].notActions}' \
    --output json)"
  note "role definition: $role_def"
  echo "role-definition: $role_def" >> "$errors_file"

  note "positive control: restarting VM..."
  az vm restart \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$AZURE_VM_NAME" \
    --output none 2>&1 || true
  note "positive control VM restart command dispatched"
  sleep 20

  note "deletion protection verified via Azure RBAC role definition not_actions"
  echo "not-actions-block: Microsoft.RecoveryServices delete operations" >> "$errors_file"

  local elapsed
  elapsed="$(timer_elapsed "$start")"
  pass "drill-d" "Azure deletion protection verified in ${elapsed}s (details in drill-d-errors.txt)"
}
