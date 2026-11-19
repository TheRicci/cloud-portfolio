#!/usr/bin/env bash
# Runs one local session action on a VM. It never talks to a cloud control plane.
set -Eeuo pipefail

COMPOSE_DIR="${COMPOSE_DIR:-/opt/cloud-portfolio/03-observability/compose}"
EVENT_DIR="${EVENT_DIR:-/var/lib/observability}"
mkdir -p "$EVENT_DIR"

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
event() { jq -cn --arg time "$(timestamp)" --arg action "$1" --argjson data "$2" '$data + {observed_at:$time, action:$action}' | tee -a "$EVENT_DIR/session-events.jsonl"; }
compose() { cd "$COMPOSE_DIR" && CLOUD="${CLOUD:?CLOUD must be aws or azure}" docker compose "$@"; }
prom_query() {
  local encoded
  encoded="$(jq -rn --arg query "$1" '$query | @uri')"
  docker exec obs-prometheus wget -qO- "http://127.0.0.1:9090/api/v1/query?query=$encoded"
}
alerts() { docker exec obs-prometheus wget -qO- http://127.0.0.1:9090/api/v1/alerts; }
alertmanager_alerts() { docker exec obs-alertmanager wget -qO- http://127.0.0.1:9093/api/v2/alerts; }
metric() { prom_query "$1" | jq -er '.data.result[0].value[1] // empty'; }
service_counter() {
  local code_class="$1"
  curl -fsS http://127.0.0.1:8080/metrics |
    awk -v metric="http_requests_total{code_class=\"$code_class\"}" '$1 == metric { total += $2 } END { print total + 0 }'
}
service_total() {
  curl -fsS http://127.0.0.1:8080/metrics |
    awk '/^http_requests_total\{/ { total += $2 } END { print total + 0 }'
}
has_prom_alert() { alerts | jq -e --arg name "$1" '.data.alerts[] | select(.labels.alertname == $name and .state == "firing")' >/dev/null; }
has_alertmanager_alert() { alertmanager_alerts | jq -e --arg name "$1" '.[] | select(.labels.alertname == $name and .status.state == "active")' >/dev/null; }

wait_for_alert() {
  local name="$1" active_at am_starts_at
  local timeout="${2:-300}"
  local deadline=$((SECONDS + timeout))
  while ((SECONDS < deadline)); do
    if has_prom_alert "$name" && has_alertmanager_alert "$name"; then
      active_at="$(alerts | jq -r --arg name "$name" '.data.alerts[] | select(.labels.alertname == $name and .state == "firing") | .activeAt' | head -1)"
      am_starts_at="$(alertmanager_alerts | jq -r --arg name "$name" '.[] | select(.labels.alertname == $name and .status.state == "active") | .startsAt' | head -1)"
      event alert_fired "$(jq -cn --arg alert "$name" --arg prometheus_active_at "$active_at" --arg alertmanager_starts_at "$am_starts_at" '{alert:$alert,prometheus_active_at:$prometheus_active_at,alertmanager_starts_at:$alertmanager_starts_at}')"
      return 0
    fi
    sleep 5
  done
  event alert_timeout "$(jq -cn --arg alert "$name" '{alert:$alert}')"
  return 1
}
wait_for_resolution() {
  local name="$1"
  local timeout="${2:-300}"
  local deadline=$((SECONDS + timeout))
  while ((SECONDS < deadline)); do
    if ! has_prom_alert "$name" && ! has_alertmanager_alert "$name"; then
      event alert_resolved "$(jq -cn --arg alert "$name" '{alert:$alert}')"
      return 0
    fi
    sleep 5
  done
  event resolution_timeout "$(jq -cn --arg alert "$name" '{alert:$alert}')"
  return 1
}
start_load() {
  systemctl is-active --quiet observability-k6.service && return 0
  systemd-run --unit=observability-k6 --collect --setenv=CLOUD="$CLOUD" /usr/bin/docker compose -f "$COMPOSE_DIR/docker-compose.yml" --profile test run --rm -e RATE=5 -e DURATION=3h k6 run /scripts/k6.js
  event load_started '{}'
}
stop_load() {
  systemctl stop observability-k6.service 2>/dev/null || true
  docker ps -q --filter "ancestor=grafana/k6:0.57.0" | xargs -r docker stop >/dev/null 2>&1 || true
  event load_stopped '{}'
}
ensure_load() {
  start_load
  local before after deadline=$((SECONDS + 90))
  before="$(metric 'sum(http_requests_total)' || echo 0)"
  while ((SECONDS < deadline)); do
    sleep 5
    after="$(metric 'sum(http_requests_total)' || echo 0)"
    awk -v before="$before" -v after="$after" 'BEGIN { exit !(after > before) }' && return 0
  done
  return 1
}
set_fault() {
  curl -fsS -X POST "http://127.0.0.1:8081/faults?error=$1&delay_ms=$2" >/dev/null
  event fault_on "$(jq -cn --arg error "$1" --arg delay_ms "$2" '{error_rate:$error,delay_ms:$delay_ms}')"
}
clear_fault() { curl -fsS -X POST 'http://127.0.0.1:8081/faults?error=0&delay_ms=0' >/dev/null || true; event fault_off '{}'; }
baseline() {
  ensure_load
  local error_rate p95 deadline=$((SECONDS + 150))
  # Wait up to 150 s for Prometheus to accumulate enough data for 2m rate queries.
  while ((SECONDS < deadline)); do
    error_rate="$(metric 'sum(rate(http_requests_total{code_class="5xx"}[2m])) / sum(rate(http_requests_total[2m]))' 2>/dev/null)" && break
    sleep 10
  done
  p95="$(metric 'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[2m])))')"
  if alerts | jq -e '.data.alerts | map(select(.state == "firing")) | length == 0' >/dev/null && awk -v error_rate="$error_rate" -v p95="$p95" 'BEGIN { exit !(error_rate == 0 && p95 < 0.3) }'; then
    event baseline_pass "$(jq -cn --arg error_rate "$error_rate" --arg p95 "$p95" '{error_rate:$error_rate,p95_seconds:$p95}')"
  else
    event baseline_fail "$(jq -cn --arg error_rate "$error_rate" --arg p95 "$p95" '{error_rate:$error_rate,p95_seconds:$p95}')"
    return 1
  fi
}
count_check() {
  stop_load
  local total_before errors_before total_after errors_after
  sleep 10
  total_before="$(service_total)"
  errors_before="$(service_counter 5xx)"
  set_fault 1 0
  for _ in {1..10}; do curl -sS -o /dev/null http://127.0.0.1:8080/work || true; done
  clear_fault
  for _ in {1..90}; do curl -fsS -o /dev/null http://127.0.0.1:8080/work; done
  total_after="$(service_total)"
  errors_after="$(service_counter 5xx)"
  start_load
  if awk -v before="$total_before" -v after="$total_after" -v errors_before="$errors_before" -v errors_after="$errors_after" 'BEGIN { exit !((after-before) == 100 && (errors_after-errors_before) == 10) }'; then
    event count_pass "$(jq -cn --arg total_before "$total_before" --arg total_after "$total_after" --arg errors_before "$errors_before" --arg errors_after "$errors_after" '{total_before:$total_before,total_after:$total_after,errors_before:$errors_before,errors_after:$errors_after}')"
  else
    event count_fail "$(jq -cn --arg total_before "$total_before" --arg total_after "$total_after" --arg errors_before "$errors_before" --arg errors_after "$errors_after" '{total_before:$total_before,total_after:$total_after,errors_before:$errors_before,errors_after:$errors_after}')"
    return 1
  fi
}
test_notification() {
  local before total failed deadline=$((SECONDS + 90))
  before="$(docker exec obs-alertmanager wget -qO- http://127.0.0.1:9093/metrics | awk '/^alertmanager_notifications_total\{ { total += $2 } END { print total + 0 }')"
  docker exec obs-prometheus wget -qO- --header='Content-Type: application/json' --post-data='[{"labels":{"alertname":"SessionNotificationTest","severity":"warning"},"annotations":{"summary":"Session notification test"},"startsAt":"2026-11-16T00:00:00Z","endsAt":"2036-11-16T00:00:00Z"}]' \
    http://alertmanager:9093/api/v2/alerts >/dev/null
  while ((SECONDS < deadline)); do
    total="$(docker exec obs-alertmanager wget -qO- http://127.0.0.1:9093/metrics | awk '/^alertmanager_notifications_total\{ { total += $2 } END { print total + 0 }')"
    failed="$(docker exec obs-alertmanager wget -qO- http://127.0.0.1:9093/metrics | awk '/^alertmanager_notifications_failed_total\{ { total += $2 } END { print total + 0 }')"
    if awk -v before="$before" -v total="$total" -v failed="$failed" 'BEGIN { exit !(total > before && failed == 0) }'; then
      docker exec obs-prometheus wget -qO- --header='Content-Type: application/json' \
        --post-data='[{"labels":{"alertname":"SessionNotificationTest","severity":"warning"},"endsAt":"2000-01-01T00:00:00Z"}]' \
        http://alertmanager:9093/api/v2/alerts > /dev/null || true
      event notification_test_pass "$(jq -cn --arg total "$total" '{notifications_total:$total}')"
      return 0
    fi
    sleep 5
  done
  docker exec obs-prometheus wget -qO- --header='Content-Type: application/json' \
    --post-data='[{"labels":{"alertname":"SessionNotificationTest","severity":"warning"},"endsAt":"2000-01-01T00:00:00Z"}]' \
    http://alertmanager:9093/api/v2/alerts > /dev/null || true
  event notification_test_fail '{}'
  return 1
}
cleanup() { clear_fault; docker start obs-service obs-alloy >/dev/null 2>&1 || true; systemctl stop observability-cpu-burn.service 2>/dev/null || true; }
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

case "${1:-}" in
  ready) alerts >/dev/null && alertmanager_alerts >/dev/null && event ready '{}' ;;
  notification-test) test_notification ;;
  baseline) baseline ;;
  count) count_check ;;
  load) ensure_load && event load_healthy '{}' ;;
  traffic-stop) stop_load ;;
  traffic-start) ensure_load && event traffic_started '{}' ;;
  fault-on) set_fault "$2" "$3" ;;
  fault-off) clear_fault ;;
  wait-alert) wait_for_alert "$2" "${3:-300}" ;;
  wait-resolved) wait_for_resolution "$2" "${3:-300}" ;;
  service-stop) docker stop obs-service >/dev/null; event service_stopped '{}' ;;
  service-start) docker start obs-service >/dev/null; event service_started '{}' ;;
  alloy-stop) docker stop obs-alloy >/dev/null; event alloy_stopped '{}' ;;
  alloy-start) docker start obs-alloy >/dev/null; event alloy_started '{}' ;;
  prom-quiet) alerts | jq -e '.data.alerts | map(select(.state == "firing")) | length == 0' >/dev/null && event prom_quiet '{}' ;;
  cpu-start) systemd-run --unit=observability-cpu-burn --collect /usr/bin/stress-ng --cpu 2 --timeout 10m; event cpu_burn_started '{}' ;;
  cpu-stop) systemctl stop observability-cpu-burn.service; event cpu_burn_stopped '{}' ;;
  *) echo "usage: vm-session.sh {ready|notification-test|baseline|count|load|traffic-stop|traffic-start|fault-on|fault-off|wait-alert|wait-resolved|service-stop|service-start|alloy-stop|alloy-start|prom-quiet|cpu-start|cpu-stop}" >&2; exit 2 ;;
esac

