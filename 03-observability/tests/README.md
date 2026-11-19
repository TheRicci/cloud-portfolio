# Test scripts

Run one cloud at a time. You normally use only **one** of the two wrapper scripts below.

## The scripts in plain language

| Script | Run it yourself? | What it does | When to use it |
|---|---|---|---|
| `run-aws-session.sh` | Yes | Starts the shared test controller in AWS-only mode. It talks to the workload and private monitoring VMs through SSM, checks local Grafana alerts, and checks the AWS CPU alarm. | After AWS Terraform apply, runtime-secret placement on both VMs, and email-subscription confirmation. |
| `run-azure-session.sh` | Yes | Starts the shared test controller in Azure-only mode. It talks to the Azure VM through Run Command and checks the Azure CPU alert. | After Azure Terraform apply, runtime-secret placement, Grafana import, and email-subscription confirmation. |
| `run-session.sh` | Usually no | Shared controller used by both wrappers. It starts the VM stack, invokes VM checks, queries Grafana, checks the native alarm, writes results, and restores stopped components. | Use only if you intentionally want `CLOUDS=aws,azure`. |
| `vm-session.sh` | No | The fast VM-local helper. It creates faults, controls k6, reads the service counters, waits for Prometheus/Alertmanager state, starts/stops CPU load, and cleans faults if interrupted. | The controller sends it to the VM automatically. |
| `check-static.sh` | Optional | Checks local project files before deployment: Terraform syntax, Compose, rules, configs, scripts, Go, JSON, and obvious literal secrets. | Run it locally if Docker Desktop and ShellCheck are installed. |

## AWS: run this

```bash
cd 03-observability
export AWS_INSTANCE_ID=i-...
export AWS_MONITORING_INSTANCE_ID=i-...
export AWS_REGION=...
export AWS_ALARM_NAME=portfolio-observability-high-cpu
bash tests/run-aws-session.sh
```

## Azure: run this

```bash
cd 03-observability
export AZURE_SUBSCRIPTION_ID=...
export AZURE_RESOURCE_GROUP=rg-portfolio-observability
export AZURE_VM_NAME=vm-portfolio-observability
export AZURE_ALERT_NAME=alert-portfolio-observability-high-cpu
export GRAFANA_URL=https://your-stack.grafana.net
export GRAFANA_TOKEN=...
bash tests/run-azure-session.sh
```

## What the selected session tests

1. Prometheus and Alertmanager respond.
2. Alertmanager can attempt and complete a synthetic notification.
3. Baseline traffic has no errors, low latency, and no firing local alerts.
4. Exactly 100 direct requests produce exactly 10 failures.
5. Warning-level errors fire local and Grafana log alerts; the native CPU alarm stays quiet.
6. Total request failures fire the critical error alert.
7. Extra latency fires the slow-response alert.
8. Stopping the service fires and resolves the service-down alert.
9. Stopping Alloy makes Grafana detect stale telemetry while local Prometheus remains quiet.
10. Stopping traffic fires and resolves the no-traffic alert.
11. CPU pressure fires the local and native CPU alarms.

Every run creates its own folder under `tests/results/`, such as `20261116T120000Z-aws/`. Keep its Markdown log, JSON results, screenshots, and any email evidence together.

