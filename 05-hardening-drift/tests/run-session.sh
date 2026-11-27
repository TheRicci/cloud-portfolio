#!/usr/bin/env bash
# One hardening session on one cloud. Usage: tests/run-session.sh aws|azure
#
# Environment:
#   REGION             required. The cloud region to use (same one every session).
#   SSH_KEY            optional. Private key path (needs .pub too). Default: ephemeral ed25519 key, deleted on exit.
#   REPO_URL           optional. Public HTTPS clone URL. Default: origin remote.
#   PULL_INTERVAL_MIN  optional. Minutes between scheduled runs on the VM. Default: 3.
#   TF_INIT_ARGS       optional. Extra arguments for terraform init (for example -backend-config=...).
#
# The script plans, asks for a typed go-ahead, applies, runs the session, writes evidence to
# tests/results/<cloud>/, and always tears down on exit.
set -euo pipefail

CLOUD="${1:-}"
if [[ "$CLOUD" != aws && "$CLOUD" != azure ]]; then
  echo "usage: $0 aws|azure" >&2
  exit 2
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
RESULTS_DIR="$ROOT/tests/results/$CLOUD"
SESSION_DIR="$ROOT/tests/.session"
mkdir -p "$RESULTS_DIR" "$SESSION_DIR"
LOG_FILE="$RESULTS_DIR/session-log.md"
RESULTS_FILE="$RESULTS_DIR/results.json"
SESSION_ENV="$SESSION_DIR/$CLOUD.env"
# shellcheck source=lib.sh
. "$HERE/lib.sh"

: >"$LOG_FILE"
echo '{}' >"$RESULTS_FILE"

FAILURES=0
APPLIED=0
TEMP_SSH_KEY=""

fail() {
  log "FAIL: $*"
  FAILURES=$((FAILURES + 1))
}

ok() {
  log "PASS: $*"
}

on_exit() {
  local rc=$?
  if (( APPLIED )); then
    log "Tearing down"
    if ! "$HERE/teardown.sh" "$CLOUD"; then
      log "TEARDOWN OR AUDIT FAILED: resources may remain and keep costing money"
      rc=1
    fi
  fi
  if [[ -n "$TEMP_SSH_KEY" ]]; then
    rm -f "$TEMP_SSH_KEY" "$TEMP_SSH_KEY.pub"
  fi
  exit "$rc"
}
trap on_exit EXIT

# ---------------------------------------------------------------- preflight
: "${REGION:?set REGION to the cloud region you will use}"
need terraform ssh scp ssh-keygen jq curl git timeout

if [[ -n "${SSH_KEY:-}" ]]; then
  [[ -f "$SSH_KEY" && -f "$SSH_KEY.pub" ]] || die "need $SSH_KEY and $SSH_KEY.pub"
  if ! ssh-keygen -y -P "" -f "$SSH_KEY" >/dev/null 2>&1; then
    PUB_B64="$(awk '{print $2}' "$SSH_KEY.pub")"
    if ! ssh-add -L 2>/dev/null | grep -qF "$PUB_B64"; then
      die "$SSH_KEY has a passphrase and is not loaded in ssh-agent; run: eval \"\$(ssh-agent -s)\" && ssh-add \"$SSH_KEY\""
    fi
  fi
else
  TEMP_SSH_KEY="$SESSION_DIR/id_ed25519_$CLOUD"
  rm -f "$TEMP_SSH_KEY" "$TEMP_SSH_KEY.pub"
  ssh-keygen -q -t ed25519 -N "" -C "hardening-lab-$CLOUD" -f "$TEMP_SSH_KEY"
  chmod 600 "$TEMP_SSH_KEY"
  SSH_KEY="$TEMP_SSH_KEY"
fi
INTERVAL_MIN="${PULL_INTERVAL_MIN:-3}"
case "$CLOUD" in
  aws)
    need aws
    aws sts get-caller-identity >/dev/null 2>&1 || die "AWS credentials are not working"
    ;;
  azure)
    need az
    az account show >/dev/null 2>&1 || die "run az login first"
    ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
    export ARM_SUBSCRIPTION_ID
    ;;
esac

REPO_SHA="$(git -C "$ROOT" rev-parse HEAD)"
PROJECT_DIR="$(git -C "$ROOT" rev-parse --show-prefix)"
PROJECT_DIR="${PROJECT_DIR%/}"
PROJECT_DIR="${PROJECT_DIR:-.}"
REPO_URL="${REPO_URL:-$(git -C "$ROOT" remote get-url origin)}"
REPO_URL="$(printf '%s' "$REPO_URL" | sed -E 's#^git@github.com:#https://github.com/#')"

confirm "Have you created a budget alert on this cloud?" yes

MY_IP="$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]')"
[[ "$MY_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "could not detect your public IPv4 address"
SESSION_ID="s$(date +%m%d%H%M)"

export TF_VAR_region="$REGION"
export TF_VAR_session_id="$SESSION_ID"
export TF_VAR_allowed_cidr="$MY_IP/32"
export TF_VAR_ssh_public_key
TF_VAR_ssh_public_key="$(cat "$SSH_KEY.pub")"
export TF_VAR_repo_url="$REPO_URL"
export TF_VAR_repo_sha="$REPO_SHA"
export TF_VAR_project_dir="$PROJECT_DIR"
export TF_VAR_pull_interval_min="$INTERVAL_MIN"
export TF_VAR_ansible_bundle_b64
TF_VAR_ansible_bundle_b64="$(tar -czf - -C "$ROOT/ansible" . | base64 | tr -d '\n')"

# Saved so teardown.sh can run later from the same machine. Git-ignored. Not secret, but personal.
{
  for v in TF_VAR_region TF_VAR_session_id TF_VAR_allowed_cidr TF_VAR_ssh_public_key \
    TF_VAR_repo_url TF_VAR_repo_sha TF_VAR_project_dir TF_VAR_pull_interval_min; do
    printf 'export %s=%q\n' "$v" "${!v}"
  done
} >"$SESSION_ENV"

res_set .meta "$(jq -n --arg cloud "$CLOUD" --arg sid "$SESSION_ID" --arg sha "$REPO_SHA" \
  --arg region "$REGION" --arg date "$(date -u +%FT%TZ)" --argjson interval "$INTERVAL_MIN" \
  '{cloud: $cloud, session_id: $sid, commit: $sha, region: $region, started_utc: $date, pull_interval_min: $interval}')"

# ---------------------------------------------------------------- plan and apply
TF_DIR="$ROOT/$CLOUD"
read -r -a INIT_ARGS <<<"${TF_INIT_ARGS:-}"
terraform -chdir="$TF_DIR" init -input=false "${INIT_ARGS[@]}"
terraform -chdir="$TF_DIR" plan -input=false -out=tfplan | tail -n 40
confirm "Review the plan above. This creates billable resources." "apply $CLOUD"

APPLIED=1 # set before apply so a half-finished apply is still cleaned up
START="$(now)"
terraform -chdir="$TF_DIR" apply -input=false tfplan | tail -n 15

IP="$(terraform -chdir="$TF_DIR" output -raw public_ip)"
SSH_USER="$(terraform -chdir="$TF_DIR" output -raw ssh_user)"

log "Waiting for SSH and cloud-init"
if ! wait_until 600 10 rssh true; then
  log "Last SSH error:"
  ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 "$SSH_USER@$IP" true 2>&1 | tee -a "$LOG_FILE" || true
  die "SSH never became reachable"
fi
rssh 'sudo cloud-init status --wait' >/dev/null || die "cloud-init reported an error"
rssh 'test -f /var/lib/hardening/bootstrap-done && test -x /usr/local/bin/hardening-pull' || die "bootstrap did not finish"
rscp "$HERE"/remote/*.sh "$SSH_USER@$IP:/tmp/" || die "could not copy remote scripts"

# ---------------------------------------------------------------- helpers
ALLOWED='ubuntu azureuser'

count_fail() { # count_fail <file>
  grep -c ' fail$' "$1" || true
}

verify_to() { # verify_to <file>; returns non-zero if the VM could not be reached
  local out
  out="$(rssh "sudo ALLOWED_USERS='$ALLOWED' bash /tmp/verify-state.sh")" || return 1
  [[ -n "$out" ]] || return 1
  printf '%s\n' "$out" >"$1"
}

last_changed() {
  rssh 'sudo tail -n 1 /var/log/hardening/runs.log' | sed -n 's/.*changed=\([0-9a-z]*\).*/\1/p'
}

scan() { # scan <phase>: host checks, Lynis score, outside probes
  local phase=$1
  verify_to "$RESULTS_DIR/host-checks-$phase.txt" || die "host checks could not run ($phase)"
  rssh 'sudo bash /tmp/lynis-score.sh' >"$RESULTS_DIR/lynis-$phase.txt" || die "Lynis could not run ($phase)"
  "$HERE/attack-from-outside.sh" "$IP" "$SSH_USER" "$SSH_KEY" >"$RESULTS_DIR/outside-$phase.txt"
  HOST_FAILED="$(count_fail "$RESULTS_DIR/host-checks-$phase.txt")"
  OUTSIDE_FAILED="$(count_fail "$RESULTS_DIR/outside-$phase.txt")"
  LYNIS_INDEX="$(sed -n 's/^hardening_index=//p' "$RESULTS_DIR/lynis-$phase.txt")"
  log "$phase: host checks failed=$HOST_FAILED, outside checks failed=$OUTSIDE_FAILED, Lynis index=${LYNIS_INDEX:-unknown}"
  res_set ".$phase" "$(jq -n --argjson h "$HOST_FAILED" --argjson o "$OUTSIDE_FAILED" --arg l "${LYNIS_INDEX:-unknown}" \
    '{host_checks_failed: $h, outside_checks_failed: $o, lynis_index: $l}')"
}

# ---------------------------------------------------------------- baseline
log "Phase 1: baseline (deliberately weak, before any hardening)"
scan baseline
if grep -q 'control_ssh_reachable pass' "$RESULTS_DIR/outside-baseline.txt"; then
  ok "outside control: SSH reachable"
else
  fail "outside control: SSH not reachable from this machine"
fi
if (( HOST_FAILED > 0 )) && grep -q 'decoy_port_8080_closed fail' "$RESULTS_DIR/outside-baseline.txt"; then
  ok "baseline is weak as intended, so there is something to fix"
else
  fail "baseline was not weak (host failures=$HOST_FAILED); the before and after comparison means little"
fi

# ---------------------------------------------------------------- harden
log "Phase 2: apply the hardening playbook"
T1="$(now)"
if rssh 'sudo /usr/local/bin/hardening-pull' >"$RESULTS_DIR/ansible-run-1.txt" 2>&1; then
  ok "first playbook run exited 0"
else
  fail "first playbook run failed; see ansible-run-1.txt"
fi
RUN1_SECONDS=$(($(now) - T1))
RUN1_CHANGED="$(last_changed)"
log "first run: ${RUN1_SECONDS}s, changed=${RUN1_CHANGED:-unknown}"

scan hardened
if (( HOST_FAILED == 0 )); then
  ok "all host checks pass after hardening"
else
  fail "$HOST_FAILED host checks still fail; see host-checks-hardened.txt"
fi
if (( OUTSIDE_FAILED == 0 )); then
  ok "all outside probes pass after hardening"
else
  fail "$OUTSIDE_FAILED outside probes still fail; see outside-hardened.txt"
fi

# ---------------------------------------------------------------- idempotence
log "Phase 3: idempotence (a second run must change nothing)"
if rssh 'sudo /usr/local/bin/hardening-pull' >"$RESULTS_DIR/ansible-run-2.txt" 2>&1; then
  RUN2_CHANGED="$(last_changed)"
  if [[ "$RUN2_CHANGED" == 0 ]]; then
    ok "second run changed 0 things"
  else
    fail "second run changed ${RUN2_CHANGED:-unknown} things; see ansible-run-2.txt"
  fi
else
  RUN2_CHANGED=unknown
  fail "second playbook run failed; see ansible-run-2.txt"
fi
res_set .apply "$(jq -n --argjson s "$RUN1_SECONDS" --arg c1 "${RUN1_CHANGED:-unknown}" --arg c2 "${RUN2_CHANGED:-unknown}" \
  '{first_run_seconds: $s, first_run_changed: $c1, second_run_changed: $c2}')"

# ---------------------------------------------------------------- drift
log "Phase 4: drift. Turn on the scheduled run, break the host, time the repair"
rssh 'sudo systemctl enable --now hardening-pull.timer' || fail "could not start the timer"
rssh 'sudo bash /tmp/break.sh' >"$RESULTS_DIR/break-output.txt" 2>&1 || fail "break script failed"
T0="$(now)"
if verify_to "$RESULTS_DIR/host-checks-broken.txt"; then
  BROKEN_COUNT="$(count_fail "$RESULTS_DIR/host-checks-broken.txt")"
  if (( BROKEN_COUNT >= 3 )); then
    ok "break took effect ($BROKEN_COUNT checks fail)"
  else
    fail "break did not take effect (only $BROKEN_COUNT checks fail)"
  fi
else
  BROKEN_COUNT=unknown
  fail "could not read host state right after the break"
fi

DEADLINE=$((T0 + INTERVAL_MIN * 60 * 3 + 120))
HEALED=false
HEAL_SECONDS=null
while (( $(now) < DEADLINE )); do
  sleep 15
  if verify_to "$RESULTS_DIR/host-checks-poll.txt" && [[ "$(count_fail "$RESULTS_DIR/host-checks-poll.txt")" == 0 ]]; then
    HEALED=true
    HEAL_SECONDS=$(($(now) - T0))
    break
  fi
done
if [[ "$HEALED" == true ]]; then
  ok "host repaired itself in ${HEAL_SECONDS}s (run interval ${INTERVAL_MIN} min)"
else
  rssh 'sudo systemctl status hardening-pull.timer hardening-pull.service --no-pager; echo "---"; sudo systemctl list-timers --all --no-pager; echo "---"; sudo journalctl -u hardening-pull.timer -u hardening-pull.service --no-pager' >"$RESULTS_DIR/timer-debug.txt" 2>&1 || true
  fail "host was not repaired within the deadline (see timer-debug.txt)"
fi
rssh 'sudo cat /var/log/hardening/runs.log' >"$RESULTS_DIR/runs.log" 2>/dev/null || true
res_set .drift "$(jq -n --argjson healed "$HEALED" --argjson secs "$HEAL_SECONDS" --arg broken "$BROKEN_COUNT" \
  '{healed: $healed, heal_seconds: $secs, checks_failing_after_break: $broken}')"

scan final
if (( OUTSIDE_FAILED == 0 )); then
  ok "outside probes pass after the repair"
else
  fail "outside probes fail after the repair"
fi

# ---------------------------------------------------------------- results
ELAPSED=$(($(now) - START))
res_set .session "$(jq -n --argjson f "$FAILURES" --argjson e "$ELAPSED" '{failures: $f, elapsed_seconds: $e, passed: ($f == 0)}')"
log "Session finished with $FAILURES failure(s) after ${ELAPSED}s. Evidence is in tests/results/$CLOUD/."
log "Next: teardown runs now. Check Cost Explorer or Cost Management tomorrow and record the actual cost in the README."

if (( FAILURES > 0 )); then
  exit 1
fi
