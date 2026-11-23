#!/usr/bin/env bash
# Shared library for Azure backup-lab drill sessions.
# Sourced by tests/azure/run.sh and Azure drills.

# --- Logging ---
note() { printf '%s  %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*" | tee -a "$LOG"; }
pass() { STATUS["$1"]=PASS; DETAIL["$1"]="$2"; note "PASS  $1 — $2"; }
fail() { STATUS["$1"]=FAIL; DETAIL["$1"]="$2"; note "FAIL  $1 — $2"; }
need() { command -v "$1" >/dev/null || { echo "missing command: $1" >&2; exit 2; }; }

# --- Timing ---
timer_start() { date +%s; }
timer_elapsed() {
  local start="$1"
  local now
  now="$(date +%s)"
  echo $(( now - start ))
}

# --- Azure VM Run-Command ---
remote_azure() {
  local command="$1"
  az vm run-command invoke \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --name "$AZURE_VM_NAME" \
    --command-id RunShellScript \
    --scripts "$command" \
    --query 'value[0].message' \
    --output tsv
}

remote() {
  remote_azure "$@"
}

# --- Azure Backup Job Polling ---
wait_backup_azure() {
  local job_name="$1" timeout="${2:-600}" elapsed=0 state
  while (( elapsed < timeout )); do
    sleep 60
    elapsed=$(( elapsed + 60 ))
    state="$(az backup job show \
      --resource-group "$AZURE_RESOURCE_GROUP" \
      --vault-name "$VAULT_NAME" \
      --name "$job_name" \
      --query properties.status --output tsv)"
    note "  backup job $job_name: $state (${elapsed}s)"
    case "$state" in
      Completed) return 0 ;;
      Failed|Cancelled) return 1 ;;
    esac
  done
  note "TIMEOUT  backup job $job_name after ${timeout}s"
  return 1
}

# --- Database helpers ---
record_last_row() {
  local result
  result="$(remote "sudo -u postgres psql -d backuplab -t -A -F'|' -c \"SELECT id, written_at FROM events ORDER BY id DESC LIMIT 1;\"")"
  LAST_ROW_ID="$(echo "$result" | cut -d'|' -f1 | tr -d '[:space:]')"
  LAST_ROW_AT="$(echo "$result" | cut -d'|' -f2 | tr -d '[:space:]')"
  note "last row: id=$LAST_ROW_ID at=$LAST_ROW_AT"
}

verify_rows() {
  local bad_count
  bad_count="$(remote "sudo -u postgres psql -d backuplab -t -A -c \"SELECT count(*) FROM events WHERE checksum != encode(sha256(payload::bytea), 'hex');\"")"
  bad_count="$(echo "$bad_count" | tr -d '[:space:]')"
  if [[ "$bad_count" == "0" ]]; then
    note "checksum verification passed — 0 corrupted rows"
    return 0
  else
    note "CHECKSUM MISMATCH — $bad_count corrupted rows"
    return 1
  fi
}

get_row_count() {
  local count
  count="$(remote "sudo -u postgres psql -d backuplab -t -A -c \"SELECT count(*) FROM events;\"")"
  echo "$count" | tr -d '[:space:]'
}

# --- File manifest (Blob Storage) ---
seed_files() {
  local manifest="$RESULTS_DIR/file-manifest.json"
  local tmpdir
  tmpdir="$(mktemp -d)"

  note "seeding 20 test files to Azure Blob Storage..."
  echo '[]' > "$manifest"
  for i in $(seq 1 20); do
    local name="testfile-$(printf '%03d' "$i").txt"
    local content="backup-lab test file $i created at $(date -u +%Y-%m-%dT%H:%M:%SZ) random=$(openssl rand -hex 16)"
    echo "$content" > "$tmpdir/$name"
    local hash
    hash="$(sha256sum "$tmpdir/$name" | cut -d' ' -f1)"

    az storage blob upload \
      --account-name "$STORAGE_ACCOUNT" \
      --container-name files \
      --name "$name" \
      --file "$tmpdir/$name" \
      --auth-mode login \
      --output none

    local entry
    entry="$(jq -cn --arg n "$name" --arg h "$hash" '{name:$n, sha256:$h}')"
    jq --argjson e "$entry" '. + [$e]' "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
  done

  rm -rf "$tmpdir"
  note "seeded 20 files, manifest at $manifest"
}

verify_files() {
  local manifest="$RESULTS_DIR/file-manifest.json"
  local tmpdir failures=0
  tmpdir="$(mktemp -d)"

  local count
  count="$(jq length "$manifest")"
  for i in $(seq 0 $(( count - 1 ))); do
    local name hash
    name="$(jq -r ".[$i].name" "$manifest")"
    hash="$(jq -r ".[$i].sha256" "$manifest")"

    az storage blob download \
      --account-name "$STORAGE_ACCOUNT" \
      --container-name files \
      --name "$name" \
      --file "$tmpdir/$name" \
      --auth-mode login \
      --output none 2>/dev/null || true

    if [[ -f "$tmpdir/$name" ]]; then
      local actual
      actual="$(sha256sum "$tmpdir/$name" | cut -d' ' -f1)"
      if [[ "$actual" != "$hash" ]]; then
        note "  MISMATCH $name: expected=$hash actual=$actual"
        failures=$(( failures + 1 ))
      fi
    else
      note "  MISSING $name"
      failures=$(( failures + 1 ))
    fi
  done

  rm -rf "$tmpdir"
  if (( failures == 0 )); then
    note "file verification passed — all 20 files match"
    return 0
  else
    note "file verification FAILED — $failures errors"
    return 1
  fi
}

# --- Results ---
write_results_json() {
  local json="$RESULTS_DIR/results.json"
  local session_end
  session_end="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  {
    echo "{"
    echo "  \"cloud\": \"azure\","
    echo "  \"session_id\": \"$RUN_ID\","
    echo "  \"session_start\": \"$SESSION_START\","
    echo "  \"session_end\": \"$session_end\","
    echo "  \"steps\": {"

    local first=true
    for key in "${!STATUS[@]}"; do
      if [[ "$first" == "true" ]]; then first=false; else echo ","; fi
      printf '    "%s": {"status": "%s", "detail": "%s"}' "$key" "${STATUS[$key]}" "${DETAIL[$key]}"
    done
    echo ""

    echo "  }"
    echo "}"
  } > "$json"
  note "results written to $json"
}
