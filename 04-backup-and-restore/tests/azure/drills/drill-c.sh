#!/usr/bin/env bash
# Drill C — File loss and recovery from Azure blob versioning/soft-delete. Sourced by tests/azure/run.sh.

run_drill_c() {
  local start
  start="$(timer_start)"
  local manifest="$RESULTS_DIR/file-manifest.json"

  local overwrite_files=() delete_files=()
  for i in $(seq 0 4); do
    overwrite_files+=("$(jq -r ".[$i].name" "$manifest")")
  done
  for i in $(seq 5 9); do
    delete_files+=("$(jq -r ".[$i].name" "$manifest")")
  done

  note "overwriting Azure blobs: ${overwrite_files[*]}"
  note "deleting Azure blobs: ${delete_files[*]}"

  for name in "${overwrite_files[@]}"; do
    local tmpf
    tmpf="$(mktemp)"
    echo "CORRUPTED CONTENT" > "$tmpf"
    az storage blob upload \
      --account-name "$STORAGE_ACCOUNT" \
      --container-name files \
      --name "$name" \
      --file "$tmpf" \
      --overwrite \
      --auth-mode login \
      --output none
    rm -f "$tmpf"
  done

  for name in "${delete_files[@]}"; do
    az storage blob delete \
      --account-name "$STORAGE_ACCOUNT" \
      --container-name files \
      --name "$name" \
      --auth-mode login \
      --output none
  done
  note "blobs corrupted and deleted"

  note "recovering blobs from versioning and soft-delete..."
  for name in "${overwrite_files[@]}"; do
    local version_id
    version_id="$(az storage blob list \
      --account-name "$STORAGE_ACCOUNT" \
      --container-name files \
      --prefix "$name" \
      --include v \
      --auth-mode login \
      --query "[?name=='$name' && isCurrentVersion==null].versionId | [0]" \
      --output tsv 2>/dev/null || true)"
    if [[ -n "$version_id" ]]; then
      az storage blob copy start \
        --account-name "$STORAGE_ACCOUNT" \
        --destination-container files \
        --destination-blob "$name" \
        --source-account-name "$STORAGE_ACCOUNT" \
        --source-container files \
        --source-blob "$name" \
        --source-blob-version "$version_id" \
        --auth-mode login \
        --output none 2>/dev/null || true
    fi
  done

  for name in "${delete_files[@]}"; do
    az storage blob undelete \
      --account-name "$STORAGE_ACCOUNT" \
      --container-name files \
      --name "$name" \
      --auth-mode login \
      --output none 2>/dev/null || true
  done

  note "Azure blob recovery complete"

  if verify_files; then
    local elapsed
    elapsed="$(timer_elapsed "$start")"
    pass "drill-c" "all blobs recovered and verified in ${elapsed}s"
  else
    local elapsed
    elapsed="$(timer_elapsed "$start")"
    fail "drill-c" "blob recovery verification failed after ${elapsed}s"
  fi
}
