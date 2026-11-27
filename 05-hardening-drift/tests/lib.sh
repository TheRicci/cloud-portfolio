#!/usr/bin/env bash
# Shared helpers. Sourced by the other scripts; not run directly.

log() {
  printf '%s %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "${LOG_FILE:-/dev/null}"
}

die() {
  log "ERROR: $*"
  exit 1
}

need() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "missing tool: $c"
  done
}

now() {
  date +%s
}

confirm() {
  local ans
  read -r -p "$1 Type '$2' to continue: " ans
  [[ "$ans" == "$2" ]] || die "not confirmed"
}

# wait_until <timeout seconds> <interval seconds> <command...>
wait_until() {
  local timeout=$1 interval=$2 start
  shift 2
  start="$(now)"
  until "$@" >/dev/null 2>&1; do
    if (( $(now) - start >= timeout )); then
      return 1
    fi
    sleep "$interval"
  done
}

# res_set <jq path> <json value>: writes into $RESULTS_FILE
res_set() {
  local tmp
  tmp="$(mktemp)"
  jq --argjson v "$2" "$1 = \$v" "$RESULTS_FILE" >"$tmp" && mv "$tmp" "$RESULTS_FILE"
}

# Needs SSH_KEY, SSH_USER and IP to be set by the caller.
rssh() {
  ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10 \
    "$SSH_USER@$IP" "$@"
}

rscp() {
  scp -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10 "$@"
}
