#!/usr/bin/env bash
# Runs one or more independent cloud sessions. Default: CLOUDS=aws.
set -Eeuo pipefail

CLOUDS="${CLOUDS:-aws}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWS_VM_SCRIPT="/opt/observability/tests/vm-session.sh"
AZURE_VM_SCRIPT="/opt/cloud-portfolio/03-observability/tests/vm-session.sh"
IFS=',' read -r -a CLOUD_LIST <<<"$CLOUDS"
for cloud in "${CLOUD_LIST[@]}"; do
  case "$cloud" in aws|azure) ;; *) echo "CLOUDS must contain aws and/or azure" >&2; exit 2 ;; esac
done

if [[ " ${CLOUD_LIST[*]} " == *" aws "* ]]; then
  : "${AWS_INSTANCE_ID:?Set the EC2 instance ID.}"
  : "${AWS_MONITORING_INSTANCE_ID:?Set the monitoring EC2 instance ID.}"
  : "${AWS_REGION:?Set the AWS region.}"
  : "${AWS_ALARM_NAME:?Set the CloudWatch alarm name.}"
fi
if [[ " ${CLOUD_LIST[*]} " == *" azure "* ]]; then
  : "${GRAFANA_URL:?Set the Grafana Cloud stack URL.}"
  : "${GRAFANA_TOKEN:?Set a read-only Grafana API token in the environment.}"
  : "${AZURE_SUBSCRIPTION_ID:?Set the Azure subscription ID.}"
  : "${AZURE_RESOURCE_GROUP:?Set the Azure resource group.}"
  : "${AZURE_VM_NAME:?Set the Azure VM name.}"
  : "${AZURE_ALERT_NAME:?Set the Azure Monitor alert name.}"
fi

RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)-${CLOUDS//,/+}}"
RESULTS_DIR="$ROOT/tests/results/$RUN_ID"
LOG="$RESULTS_DIR/session-log.md"
JSON="$RESULTS_DIR/results.json"
mkdir -p "$RESULTS_DIR"
: >"$LOG"
declare -A STATUS DETAIL
SESSION_START="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

note() { printf '%s %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*" | tee -a "$LOG"; }
pass() { STATUS["$1"]=PASS; DETAIL["$1"]="$2"; note "PASS $1 - $2"; }
fail() { STATUS["$1"]=FAIL; DETAIL["$1"]="$2"; note "FAIL $1 - $2"; }
need() { command -v "$1" >/dev/null || { echo "missing command: $1" >&2; exit 2; }; }
for command in curl jq; do need "$command"; done
[[ " ${CLOUD_LIST[*]} " == *" aws "* ]] && need aws
[[ " ${CLOUD_LIST[*]} " == *" azure "* ]] && need az

remote_aws_instance() {
  local instance_id="$1" command="$2" command_id state parameters
  parameters="$(jq -cn --arg command "$command" '{commands:[$command]}')"
  command_id="$(aws ssm send-command --region "$AWS_REGION" --document-name AWS-RunShellScript --instance-ids "$instance_id" --parameters "$parameters" --query Command.CommandId --output text)"
  while :; do
    state="$(aws ssm get-command-invocation --region "$AWS_REGION" --command-id "$command_id" --instance-id "$instance_id" --query Status --output text 2>/dev/null || true)"
    case "$state" in
      Success) aws ssm get-command-invocation --region "$AWS_REGION" --command-id "$command_id" --instance-id "$instance_id" --query StandardOutputContent --output text; return 0 ;;
      Failed|Cancelled|TimedOut) aws ssm get-command-invocation --region "$AWS_REGION" --command-id "$command_id" --instance-id "$instance_id" --query StandardErrorContent --output text >&2; return 1 ;;
    esac
    sleep 3
  done
}
remote_aws() { remote_aws_instance "$AWS_INSTANCE_ID" "$1"; }
remote_monitor() { remote_aws_instance "$AWS_MONITORING_INSTANCE_ID" "$1"; }
remote_azure() {
  az vm run-command invoke --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_VM_NAME" --command-id RunShellScript --scripts "$1" --query 'value[0].message' --output tsv
}
remote() { case "$1" in aws) remote_aws "$2" ;; azure) remote_azure "$2" ;; esac; }
vm_command() {
  case "$1" in
    aws) remote aws "sudo CLOUD=aws COMPOSE_DIR=/opt/observability/compose $AWS_VM_SCRIPT $2" ;;
    azure) remote azure "sudo CLOUD=azure $AZURE_VM_SCRIPT $2" ;;
  esac
}

run_clouds() {
  local action="$*" temp result=0
  temp="$(mktemp -d)"
  local -a pids=()
  for cloud in "${CLOUD_LIST[@]}"; do
    vm_command "$cloud" "$action" >"$temp/$cloud.out" 2>&1 &
    pids+=("$!")
  done
  for pid in "${pids[@]}"; do wait "$pid" || result=1; done
  for cloud in "${CLOUD_LIST[@]}"; do sed "s/^/[$cloud] /" "$temp/$cloud.out" | tee -a "$LOG"; done
  rm -rf "$temp"
  return "$result"
}
wait_for() {
  local description="$1" timeout="$2"; shift 2
  local deadline=$((SECONDS + timeout))
  while ((SECONDS < deadline)); do "$@" && return 0; sleep 15; done
  note "Timed out waiting for $description"
  return 1
}
grafana_alert_time() {
  local name="$1" after="$2" cloud="$3"
  case "$cloud" in
    aws) remote_monitor "sudo /opt/monitoring/monitor-session.sh alert-time $(printf '%q' "$name") $(printf '%q' "$after") $(printf '%q' "$cloud")" ;;
    azure) curl --fail --silent --show-error -H "Authorization: Bearer $GRAFANA_TOKEN" "$GRAFANA_URL/api/alertmanager/grafana/api/v2/alerts" |
      jq -er --arg name "$name" --arg after "$after" --arg cloud "$cloud" '.[] | select(.labels.alertname == $name and .labels.cloud == $cloud and .status.state == "active" and .startsAt >= $after) | .startsAt' | head -1 ;;
  esac
}
native_alarm_time() {
  local cloud="$1" after="$2"
  case "$cloud" in
    aws) aws cloudwatch describe-alarms --region "$AWS_REGION" --alarm-names "$AWS_ALARM_NAME" --query 'MetricAlarms[0].{state:StateValue,time:StateUpdatedTimestamp}' --output json | jq -er --arg after "$after" 'select(.state == "ALARM" and .time >= $after) | .time' ;;
    azure) az rest --method get --url "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID/providers/Microsoft.AlertsManagement/alerts?api-version=2023-07-12-preview" --output json | jq -er --arg name "$AZURE_ALERT_NAME" --arg after "$after" '.value[] | select(.properties.essentials.alertRule == $name and .properties.essentials.monitorCondition == "Fired" and .properties.essentials.startDateTime >= $after) | .properties.essentials.startDateTime' | head -1 ;;
  esac
}
native_quiet() {
  local after="$1"
  for cloud in "${CLOUD_LIST[@]}"; do native_alarm_time "$cloud" "$after" >/dev/null && return 1; done
}
wait_for_grafana_all() {
  local name="$1" after="$2" cloud observed
  for cloud in "${CLOUD_LIST[@]}"; do
    observed="$(wait_for "$name from $cloud" 600 grafana_alert_time "$name" "$after" "$cloud" || true)"
    [[ -n "$observed" ]] || { note "Timed out or failed waiting for Grafana alert '$name' from $cloud"; return 1; }
    note "Observed Grafana alert '$name' for $cloud at $observed"
  done
}
wait_for_native_all() {
  local after="$1" cloud observed
  for cloud in "${CLOUD_LIST[@]}"; do
    observed="$(wait_for "native CPU alarm from $cloud" 900 native_alarm_time "$cloud" "$after" || true)"
    [[ -n "$observed" ]] || { note "Timed out or failed waiting for native CPU alarm from $cloud"; return 1; }
    note "Observed native CPU alarm for $cloud at $observed"
  done
}
cleanup() {
  note "Cleanup: clearing faults, stopping CPU burn, and restoring containers."
  run_clouds fault-off || true
  run_clouds cpu-stop || true
  run_clouds traffic-stop || true
  run_clouds service-start || true
  run_clouds alloy-start || true
}
write_results() {
  local checks
  checks="$(for key in "${!STATUS[@]}"; do jq -cn --arg key "$key" --arg status "${STATUS[$key]}" --arg detail "${DETAIL[$key]}" '{key:$key,value:{status:$status,detail:$detail}}'; done | jq -s 'from_entries')"
  jq -n --arg started "$SESSION_START" --arg finished "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" --arg clouds "$CLOUDS" --argjson checks "$checks" '{started:$started,finished:$finished,clouds:$clouds,checks:$checks}' >"$JSON"
}
on_exit() { local code=$?; cleanup; write_results; exit "$code"; }
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ " ${CLOUD_LIST[*]} " == *" aws "* ]]; then
  remote_monitor "sudo /usr/local/bin/start-monitoring"
fi
for cloud in "${CLOUD_LIST[@]}"; do remote "$cloud" "sudo /usr/local/bin/start-observability $cloud"; done

run_clouds ready && pass ready "Prometheus and Alertmanager APIs responded." || fail ready "A VM-local monitoring API did not respond."
run_clouds notification-test && pass notification "Alertmanager completed a synthetic notification with no failed deliveries." || fail notification "Alertmanager notification delivery did not succeed."
run_clouds baseline && pass baseline "Computed a clean baseline from Prometheus data." || fail baseline "The VM-side baseline computation failed."
run_clouds count && pass count "Stopped k6 and compared direct service counter deltas." || fail count "The direct service counter delta was not exactly 100 total and 10 5xx."

run_clouds load || { fail load "Traffic was not increasing before faults."; exit 1; }
step_started="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
run_clouds 'fault-on 0.2 0' && run_clouds 'wait-alert HighErrorRate 300' && pass error_fault "HighErrorRate fired with VM-side source timestamps." || fail error_fault "HighErrorRate was not observed."
wait_for_grafana_all "Service error log burst" "$step_started" && pass error_log_alert "Grafana observed fresh Loki error logs." || fail error_log_alert "Grafana did not observe fresh Loki error logs."
native_quiet "$step_started" && pass error_native_quiet "No native CPU alarm fired during the error fault." || fail error_native_quiet "A native CPU alarm fired during the error fault."
run_clouds fault-off || true
run_clouds 'wait-resolved HighErrorRate 300' && pass error_resolution "HighErrorRate resolved." || fail error_resolution "HighErrorRate did not resolve."

run_clouds load || { fail total_failure_load "Traffic was not increasing before total failure."; exit 1; }
run_clouds 'fault-on 1 0' && run_clouds 'wait-alert CriticalErrorRate 300' && pass critical_error_fault "CriticalErrorRate fired." || fail critical_error_fault "CriticalErrorRate was not observed."
run_clouds fault-off || true
run_clouds 'wait-resolved CriticalErrorRate 300' && pass critical_error_resolution "CriticalErrorRate resolved." || fail critical_error_resolution "CriticalErrorRate did not resolve."

run_clouds load || { fail latency_load "Traffic was not increasing before latency fault."; exit 1; }
run_clouds 'fault-on 0 500' && run_clouds 'wait-alert SlowResponses 300' && pass latency_fault "SlowResponses fired." || fail latency_fault "SlowResponses was not observed."
run_clouds fault-off || true
run_clouds 'wait-resolved SlowResponses 300' && pass latency_resolution "SlowResponses resolved." || fail latency_resolution "SlowResponses did not resolve."

run_clouds service-stop && run_clouds 'wait-alert ServiceDown 300' && run_clouds service-start && run_clouds 'wait-resolved ServiceDown 300' && pass service_down "ServiceDown fired and resolved." || fail service_down "ServiceDown did not complete."

step_started="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
run_clouds alloy-stop || true
wait_for_grafana_all "No data from a VM" "$step_started" && pass pipeline_cut "Grafana observed fresh per-cloud stale-sample alerts." || fail pipeline_cut "Grafana no-data alert was not observed."
run_clouds prom-quiet && pass pipeline_prom_quiet "Prometheus alerts remained quiet after the pipeline-cut alert fired." || fail pipeline_prom_quiet "A Prometheus alert fired during the Alloy cut."
run_clouds alloy-start || true

run_clouds traffic-stop || true
run_clouds 'wait-alert NoTraffic 540' && pass no_traffic "NoTraffic fired while the service remained healthy." || fail no_traffic "NoTraffic was not observed."
run_clouds traffic-start || true
run_clouds 'wait-resolved NoTraffic 300' && pass no_traffic_resolution "NoTraffic resolved after traffic resumed." || fail no_traffic_resolution "NoTraffic did not resolve."

step_started="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
run_clouds cpu-start && run_clouds 'wait-alert HighCPU 300' && pass cpu_prometheus "HighCPU fired." || fail cpu_prometheus "HighCPU was not observed."
wait_for_native_all "$step_started" && pass cpu_burn "Native CPU alarms fired; API timestamps were observed after the burn started." || fail cpu_burn "A native CPU alarm was not observed."
run_clouds cpu-stop || true
run_clouds 'wait-resolved HighCPU 300' && pass cpu_resolution "HighCPU resolved." || fail cpu_resolution "HighCPU did not resolve."

if printf '%s\n' "${STATUS[@]}" | grep -qx FAIL; then exit 1; fi

