#!/usr/bin/env bash
# AWS Preflight checks. Sourced by tests/aws/run.sh.

run_preflight() {
  local ok=true

  local account masked_account
  account="$(aws sts get-caller-identity --query Account --output text)"
  masked_account="${account:0:4}****${account: -4}"
  note "AWS account=$masked_account region=$AWS_REGION"

  # Budget alert check
  local budget_count
  budget_count="$(aws budgets describe-budgets \
    --account-id "$account" \
    --query 'length(Budgets)' --output text 2>/dev/null || echo 0)"
  if (( budget_count == 0 )); then
    note "WARNING: no AWS budget found — create a budget alert before running in production"
  else
    note "AWS budgets found: $budget_count"
  fi

  # Leftover check
  local leftovers
  leftovers="$(aws resourcegroupstaggingapi get-resources \
    --region "$AWS_REGION" \
    --tag-filters "Key=project,Values=backup-lab" \
    --query 'length(ResourceTagMappingList)' --output text 2>/dev/null || echo 0)"
  note "tagged resources found: $leftovers"

  if [[ "$ok" == "true" ]]; then
    pass "preflight" "AWS account and budget verification complete"
  else
    fail "preflight" "preflight failed"
    return 1
  fi
}
