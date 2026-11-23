#!/usr/bin/env bash
# Drill B — Bad data, restore from logical dump. Sourced by tests/aws/run.sh.

run_drill_b() {
  local start
  start="$(timer_start)"

  record_last_row
  local pre_mistake_id="$LAST_ROW_ID"
  note "pre-mistake last row: id=$pre_mistake_id"

  local delete_threshold=$(( pre_mistake_id / 2 ))
  note "running bad DELETE: id > $delete_threshold"
  remote "sudo -u postgres psql -d backuplab -c \"DELETE FROM events WHERE id > $delete_threshold;\""

  local post_delete_count
  post_delete_count="$(get_row_count)"
  note "rows after bad delete: $post_delete_count (was: $pre_mistake_id)"

  local dump_name="dump-${RUN_ID}.sql"
  note "restoring from logical dump: $dump_name"

  remote "export PATH=\$PATH:/usr/local/bin; aws s3 cp s3://$BUCKET_NAME/dumps/$dump_name /tmp/$dump_name && sudo -u postgres psql -c 'CREATE DATABASE backuplab_restored;' && sudo -u postgres psql -d backuplab_restored -f /tmp/$dump_name" || {
    fail "drill-b" "restore from dump failed"
    return 1
  }

  local restored_count
  restored_count="$(remote "sudo -u postgres psql -d backuplab_restored -t -A -c 'SELECT count(*) FROM events;'")"
  restored_count="$(echo "$restored_count" | tr -d '[:space:]')"
  note "rows in restored database: $restored_count"

  local bad_count
  bad_count="$(remote "sudo -u postgres psql -d backuplab_restored -t -A -c \"SELECT count(*) FROM events WHERE checksum != encode(sha256(payload::bytea), 'hex');\"")"
  bad_count="$(echo "$bad_count" | tr -d '[:space:]')"

  local dump_max_id
  dump_max_id="$(remote "sudo -u postgres psql -d backuplab_restored -t -A -c 'SELECT max(id) FROM events;'")"
  dump_max_id="$(echo "$dump_max_id" | tr -d '[:space:]')"
  local rows_lost=$(( pre_mistake_id - dump_max_id ))
  if (( rows_lost < 0 )); then rows_lost=0; fi

  remote "sudo -u postgres psql -c 'DROP DATABASE IF EXISTS backuplab_restored;'" || true

  note "restoring original backuplab database from dump..."
  remote "sudo -u postgres psql -d backuplab -c 'DELETE FROM events;' && sudo -u postgres psql -d backuplab -f /tmp/$dump_name" || true

  local elapsed
  elapsed="$(timer_elapsed "$start")"

  if [[ "$bad_count" == "0" ]]; then
    pass "drill-b" "checksums OK. rows_lost=$rows_lost (RPO gap). RTO=${elapsed}s"
  else
    fail "drill-b" "$bad_count corrupted rows in restored dump"
  fi
}
