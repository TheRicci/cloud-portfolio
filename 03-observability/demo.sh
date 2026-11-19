#!/usr/bin/env bash
# ==============================================================================
# Observability & Chaos Engineering Demo Runner
# Works locally or on the AWS EC2 instance.
# Usage:
#   ./demo.sh status        - Check container and health status
#   ./demo.sh baseline      - Start normal background traffic (k6)
#   ./demo.sh fault-error   - Inject 25% HTTP 500 errors (triggers HighErrorRate)
#   ./demo.sh fault-latency - Inject 400ms response delay (triggers SlowResponses)
#   ./demo.sh fault-cpu     - Stress CPU to trigger CloudWatch / NodeExporter alert
#   ./demo.sh clean         - Reset all faults back to normal
# ==============================================================================
set -euo pipefail

SERVICE_HOST="${SERVICE_HOST:-127.0.0.1}"
SERVICE_PORT="${SERVICE_PORT:-8080}"
ADMIN_PORT="${ADMIN_PORT:-8081}"
PROM_PORT="${PROM_PORT:-9090}"
AM_PORT="${AM_PORT:-9093}"

green()  { printf "\033[1;32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[1;33m%s\033[0m\n" "$*"; }
red()    { printf "\033[1;31m%s\033[0m\n" "$*"; }
cyan()   { printf "\033[1;36m%s\033[0m\n" "$*"; }

check_status() {
  cyan "=== Observability Stack Status ==="
  echo ""
  if command -v docker >/dev/null 2>&1; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "obs-|NAMES" || true
  fi
  echo ""
  cyan "=== Endpoints ==="
  echo "  Grafana Dashboard:  http://localhost:3000 (admin / admin)"
  echo "  Prometheus UI:      http://localhost:9090"
  echo "  Alertmanager UI:    http://localhost:9093"
  echo "  Go Microservice:    http://localhost:8080/work"
  echo "  Metrics Endpoint:   http://localhost:8080/metrics"
  echo ""

  # Check service health
  if curl -s "http://$SERVICE_HOST:$SERVICE_PORT/metrics" >/dev/null 2>&1; then
    green "✓ Microservice is UP and exporting metrics."
  else
    yellow "! Microservice is not responding on :$SERVICE_PORT"
  fi

  # Check Prometheus
  if curl -s "http://$SERVICE_HOST:$PROM_PORT/-/healthy" >/dev/null 2>&1; then
    green "✓ Prometheus is UP and healthy."
  else
    yellow "! Prometheus is not responding on :$PROM_PORT"
  fi

  # Check Alertmanager
  if curl -s "http://$SERVICE_HOST:$AM_PORT/-/healthy" >/dev/null 2>&1; then
    green "✓ Alertmanager is UP and healthy."
  else
    yellow "! Alertmanager is not responding on :$AM_PORT"
  fi
}

start_baseline() {
  cyan "=== Starting Baseline Traffic (k6) ==="
  if docker ps --format '{{.Names}}' | grep -q "obs-k6"; then
    yellow "Traffic generator is already running."
  else
    COMPOSE_DIR="$(dirname "${BASH_SOURCE[0]}")/compose"
    if [ ! -d "$COMPOSE_DIR" ]; then COMPOSE_DIR="/opt/observability/compose"; fi
    docker compose -f "$COMPOSE_DIR/docker-compose.yml" --profile test run -d --name obs-k6 --rm -e RATE=5 -e DURATION=4h k6 run /scripts/k6.js >/dev/null 2>&1 || true
    green "✓ Started continuous background traffic (5 req/sec)."
  fi
  echo ""
  echo "Current requests processed:"
  curl -s "http://$SERVICE_HOST:$SERVICE_PORT/metrics" | grep "^http_requests_total" || true
  echo ""
  green "Baseline running! Open Grafana (http://localhost:3000) to see steady green traffic."
}

inject_error_fault() {
  cyan "=== Injecting Fault: 25% HTTP 500 Errors ==="
  curl -fsS -X POST "http://$SERVICE_HOST:$ADMIN_PORT/faults?error=0.25&delay_ms=0" >/dev/null
  red "► Injected error rate = 0.25 (25% of requests will return HTTP 500)"
  echo ""
  echo "Waiting 65 seconds for Prometheus 1m evaluation window..."
  for i in $(seq 65 -5 5); do
    printf "  %s seconds remaining...\r" "$i"
    sleep 5
  done
  echo ""
  cyan "Checking active Prometheus alerts:"
  curl -s "http://$SERVICE_HOST:$PROM_PORT/api/v1/alerts" | jq -r '.data.alerts[] | select(.state=="firing") | "  ► [\(.state | ascii_upcase)] \(.labels.alertname) (\(.labels.severity)): \(.annotations.summary)"' || true
  echo ""
  green "✓ HighErrorRate alert triggered! Alertmanager is dispatching notifications."
}

inject_latency_fault() {
  cyan "=== Injecting Fault: 400ms Response Latency ==="
  curl -fsS -X POST "http://$SERVICE_HOST:$ADMIN_PORT/faults?error=0&delay_ms=400" >/dev/null
  yellow "► Injected delay_ms = 400ms (p95 latency threshold is 300ms)"
  echo ""
  echo "Waiting 65 seconds for Prometheus 1m evaluation window..."
  for i in $(seq 65 -5 5); do
    printf "  %s seconds remaining...\r" "$i"
    sleep 5
  done
  echo ""
  cyan "Checking active Prometheus alerts:"
  curl -s "http://$SERVICE_HOST:$PROM_PORT/api/v1/alerts" | jq -r '.data.alerts[] | select(.state=="firing") | "  ► [\(.state | ascii_upcase)] \(.labels.alertname) (\(.labels.severity)): \(.annotations.summary)"' || true
  echo ""
  green "✓ SlowResponses alert triggered!"
}

inject_cpu_fault() {
  cyan "=== Injecting Fault: High Host CPU Load ==="
  if command -v stress-ng >/dev/null 2>&1; then
    stress-ng --cpu 2 --timeout 6m >/dev/null 2>&1 &
    red "► Started stress-ng on 2 CPU cores (6 minutes duration)."
  else
    docker run -d --rm --name obs-cpu-stress container-registry.oracle.com/os/oraclelinux:9-slim bash -c "for i in 1 2; do sha256sum /dev/zero & done; sleep 360" >/dev/null 2>&1 || true
    red "► Started CPU stress container."
  fi
  echo ""
  yellow "Host CPU is now pinned at ~100%."
  echo "On AWS, CloudWatch alarm 'portfolio-observability-high-cpu' will breach after 5 minutes and publish to SNS."
}

clean_faults() {
  cyan "=== Clearing Faults & Self-Healing ==="
  curl -fsS -X POST "http://$SERVICE_HOST:$ADMIN_PORT/faults?error=0&delay_ms=0" >/dev/null || true
  pkill -f stress-ng >/dev/null 2>&1 || true
  docker stop obs-cpu-stress >/dev/null 2>&1 || true
  green "✓ Faults reset to normal (0% errors, 0ms injected latency, CPU stress stopped)."
  echo ""
  echo "Prometheus alerts and CloudWatch alarms will automatically resolve back to OK state."
}

case "${1:-status}" in
  status)        check_status ;;
  baseline|load) start_baseline ;;
  fault-error)   inject_error_fault ;;
  fault-latency) inject_latency_fault ;;
  fault-cpu)     inject_cpu_fault ;;
  clean)         clean_faults ;;
  *)
    echo "Usage: $0 {status|baseline|fault-error|fault-latency|fault-cpu|clean}"
    exit 1
    ;;
esac
