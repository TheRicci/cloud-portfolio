#!/usr/bin/env bash
# Shared library for AWS backup-lab drill sessions.
# Sourced by tests/aws/run.sh and AWS drills.

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

# --- AWS SSM Remote Execution ---
remote_aws() {
  local command="$1" timeout="${2:-300}"
  local command_id state elapsed=0
  local parameters
  parameters="$(jq -cn --arg cmd "$command" '{"commands":[$cmd]}')"
  command_id="$(aws ssm send-command \
    --region "$AWS_REGION" \
    --document-name AWS-RunShellScript \
    --instance-ids "$AWS_INSTANCE_ID" \
    --parameters "$parameters" \
    --query Command.CommandId \
    --output text)"

  while (( elapsed < timeout )); do
    sleep 5
    elapsed=$(( elapsed + 5 ))
    state="$(aws ssm get-command-invocation \
      --region "$AWS_REGION" \
      --command-id "$command_id" \
      --instance-id "$AWS_INSTANCE_ID" \
      --query Status --output text 2>/dev/null || echo "Pending")"
    case "$state" in
      Success)
        aws ssm get-command-invocation \
          --region "$AWS_REGION" \
          --command-id "$command_id" \
          --instance-id "$AWS_INSTANCE_ID" \
          --query StandardOutputContent --output text
        return 0
        ;;
      Failed|Cancelled|TimedOut)
        aws ssm get-command-invocation \
          --region "$AWS_REGION" \
          --command-id "$command_id" \
          --instance-id "$AWS_INSTANCE_ID" \
          --query StandardErrorContent --output text >&2
        return 1
        ;;
    esac
  done
  note "TIMEOUT  SSM command $command_id after ${timeout}s"
  return 1
}

remote() {
  remote_aws "$@"
}

# --- AWS Backup Job Polling ---
wait_backup_aws() {
  local job_id="$1" timeout="${2:-600}" elapsed=0 state msg
  while (( elapsed < timeout )); do
    sleep 60
    elapsed=$(( elapsed + 60 ))
    state="$(aws backup describe-backup-job \
      --region "$AWS_REGION" \
      --backup-job-id "$job_id" \
      --query State --output text 2>/dev/null || echo "UNKNOWN")"
    msg="$(aws backup describe-backup-job \
      --region "$AWS_REGION" \
      --backup-job-id "$job_id" \
      --query StatusMessage --output text 2>/dev/null || true)"
    if [[ -n "$msg" && "$msg" != "None" ]]; then
      note "  backup job $job_id: $state (${elapsed}s) — $msg"
    else
      note "  backup job $job_id: $state (${elapsed}s)"
    fi
    case "$state" in
      COMPLETED) return 0 ;;
      FAILED|ABORTED|EXPIRED) return 1 ;;
    esac
  done
  note "TIMEOUT  backup job $job_id after ${timeout}s"
  return 1
}

wait_restore_aws() {
  local job_id="$1" timeout="${2:-600}" elapsed=0 state msg
  while (( elapsed < timeout )); do
    sleep 60
    elapsed=$(( elapsed + 60 ))
    state="$(aws backup describe-restore-job \
      --region "$AWS_REGION" \
      --restore-job-id "$job_id" \
      --query Status --output text 2>/dev/null || echo "UNKNOWN")"
    msg="$(aws backup describe-restore-job \
      --region "$AWS_REGION" \
      --restore-job-id "$job_id" \
      --query StatusMessage --output text 2>/dev/null || true)"
    if [[ -n "$msg" && "$msg" != "None" ]]; then
      note "  restore job $job_id: $state (${elapsed}s) — $msg"
    else
      note "  restore job $job_id: $state (${elapsed}s)"
    fi
    case "$state" in
      COMPLETED) return 0 ;;
      FAILED|ABORTED) return 1 ;;
    esac
  done
  note "TIMEOUT  restore job $job_id after ${timeout}s"
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

# --- File manifest (S3) ---
seed_files() {
  local manifest="$RESULTS_DIR/file-manifest.json"
  local tmpdir
  tmpdir="$(mktemp -d)"

  note "seeding 20 test files to S3..."
  echo '[]' > "$manifest"
  for i in $(seq 1 20); do
    local name="testfile-$(printf '%03d' "$i").txt"
    local content="backup-lab test file $i created at $(date -u +%Y-%m-%dT%H:%M:%SZ) random=$(openssl rand -hex 16)"
    echo "$content" > "$tmpdir/$name"
    local hash
    hash="$(sha256sum "$tmpdir/$name" | cut -d' ' -f1)"

    aws s3 cp "$tmpdir/$name" "s3://$BUCKET_NAME/files/$name" --region "$AWS_REGION" --quiet

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

    aws s3 cp "s3://$BUCKET_NAME/files/$name" "$tmpdir/$name" --region "$AWS_REGION" --quiet 2>/dev/null || true

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
    echo "  \"cloud\": \"aws\","
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
