#!/usr/bin/env bash
# Azure Preflight checks. Sourced by tests/azure/run.sh.

run_preflight() {
  local ok=true

  local sub masked_sub
  sub="$(az account show --query id --output tsv)"
  masked_sub="${sub:0:4}****${sub: -4}"
  note "Azure subscription=$masked_sub location=$AZURE_LOCATION"

  if [[ "$sub" != "$AZURE_SUBSCRIPTION_ID" ]]; then
    note "SUBSCRIPTION MISMATCH: expected $AZURE_SUBSCRIPTION_ID got $sub"
    ok=false
  fi

  local budget_count
  budget_count="$(az consumption budget list \
    --query 'length([])' --output tsv 2>/dev/null || echo 0)"
  if (( budget_count == 0 )); then
    note "WARNING: no Azure budget found — recommend setting a budget alert in Cost Management"
  else
    note "Azure budgets found: $budget_count"
  fi

  local leftovers
  leftovers="$(az resource list \
    --tag project=backup-lab \
    --query 'length([])' --output tsv 2>/dev/null || echo 0)"
  note "tagged resources currently present (includes deployed resources): $leftovers"

  if [[ "$ok" == "true" ]]; then
    pass "preflight" "Azure subscription and preflight verification complete"
  else
    fail "preflight" "preflight failed"
    return 1
  fi
}
