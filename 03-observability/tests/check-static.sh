#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

require() { command -v "$1" >/dev/null || { echo "missing required command: $1" >&2; exit 2; }; }
for command in docker terraform jq shellcheck python3 rg go; do require "$command"; done

forbidden_word="s""lo"
if rg -n -i "\\b${forbidden_word}s?\\b" --glob '!tests/check-static.sh' .; then
  echo "Disallowed terminology was found in this project." >&2
  exit 1
fi
terraform fmt -check -recursive
for root in aws azure; do
  terraform -chdir="$root" init -backend=false -input=false >/dev/null
  terraform -chdir="$root" validate
done

CLOUD=aws RUNTIME_ENV_FILE="$ROOT/compose/runtime.env.example" docker compose -f compose/docker-compose.yml --env-file compose/runtime.env.example config --quiet
docker run --rm -v "$ROOT/compose:/work:ro" prom/prometheus:v3.5.0 promtool check rules /work/rules.yml
docker run --rm -v "$ROOT/compose:/work:ro" prom/prometheus:v3.5.0 promtool check config /work/prometheus.yml
docker run --rm -v "$ROOT/compose:/work:ro" prom/prometheus:v3.5.0 promtool test rules /work/rules.test.yml

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
STATIC_CHECK_ONLY=placeholder
SMTP_SMARTHOST=smtp.example.com:587 SMTP_FROM=sender@example.com SMTP_USERNAME=sender@example.com SMTP_PASSWORD=$STATIC_CHECK_ONLY ALERT_EMAIL=recipient@example.com \
  python3 compose/render_alertmanager.py compose/alertmanager.yml.tmpl "$tmpdir/alertmanager.yml"
docker run --rm -v "$tmpdir:/work:ro" prom/alertmanager:v0.28.1 amtool check-config /work/alertmanager.yml

shellcheck tests/check-static.sh tests/run-session.sh tests/vm-session.sh
(cd service && go test ./...)
jq empty grafana/dashboard.json grafana/no-data-alert.json grafana/error-log-burst-alert.json
if rg -n -i --glob '!runtime.env.example' --glob '!backend.tf.example' --glob '!*.lock.hcl' --glob '!tests/check-static.sh' '^(.*_)?(token|password|api_key|webhook)=[^.$[:space:]][^[:space:]]+' .; then
  echo "A likely literal secret was found." >&2
  exit 1
fi
echo "Static checks passed."

