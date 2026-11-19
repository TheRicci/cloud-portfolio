#!/usr/bin/env bash
# Queries the private Grafana instance from the monitoring VM itself.
set -Eeuo pipefail

set -a
. /etc/observability/monitoring.env
set +a

alerts() {
  curl --fail --silent --show-error \
    --user "$GF_SECURITY_ADMIN_USER:$GF_SECURITY_ADMIN_PASSWORD" \
    http://127.0.0.1:3000/api/alertmanager/grafana/api/v2/alerts
}

case "${1:-}" in
  alert-time)
    alerts | jq -er --arg name "$2" --arg after "$3" --arg cloud "$4" \
      '.[] | select(.labels.alertname == $name and .labels.cloud == $cloud and .status.state == "active" and .startsAt >= $after) | .startsAt' | head -1
    ;;
  *)
    echo "usage: monitor-session.sh alert-time ALERT_NAME AFTER CLOUD" >&2
    exit 2
    ;;
esac
