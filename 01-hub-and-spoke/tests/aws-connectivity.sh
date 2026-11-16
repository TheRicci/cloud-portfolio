#!/usr/bin/env bash
# AWS validation matrix. SSM interface endpoints keep this test private.
# Usage: ./aws-connectivity.sh <spoke1-id> <spoke2-id> <nva-id> <spoke1-ip> <spoke2-ip> <nva-ip>

set -euo pipefail

SPOKE1_ID="${1:?Usage: $0 <spoke1-id> <spoke2-id> <nva-id> <spoke1-ip> <spoke2-ip> <nva-ip>}"
SPOKE2_ID="${2:?}"
NVA_ID="${3:?}"
SPOKE1_IP="${4:?}"
SPOKE2_IP="${5:?}"
NVA_IP="${6:?}"
# Evidence is intentionally printed to the terminal. Save the complete output
# manually in ../evidence/ after reviewing it.

run_on_instance() {
  local instance_id="$1" command="$2" command_id encoded_command

  # AWS CLI shorthand parameters are not safe for shell syntax such as quotes,
  # redirects, or &&. Send a simple base64 decoder command instead.
  encoded_command=$(printf '%s' "$command" | base64 | tr -d '\n')
  if ! command_id=$(aws ssm send-command --instance-ids "$instance_id" --document-name AWS-RunShellScript \
    --parameters "{\"commands\":[\"echo $encoded_command | base64 -d | bash\"]}" \
    --query 'Command.CommandId' --output text); then
    printf 'COMMAND_FAILED\n'
    return 0
  fi

  if ! aws ssm wait command-executed --command-id "$command_id" --instance-id "$instance_id"; then
    printf 'COMMAND_FAILED\n'
    return 0
  fi

  if ! aws ssm get-command-invocation --command-id "$command_id" --instance-id "$instance_id" \
    --query 'StandardOutputContent' --output text; then
    printf 'COMMAND_FAILED\n'
  fi
}

local_service_result() {
  run_on_instance "$1" "cloud-init status --wait >/dev/null 2>&1 && timeout 5 curl -fsS --connect-timeout 5 http://127.0.0.1:8443/ >/dev/null 2>&1 && echo REACHABLE || echo BLOCKED"
}

http_result() {
  run_on_instance "$1" "timeout 5 curl -fsS --connect-timeout 5 http://$2:8443/ >/dev/null 2>&1 && echo REACHABLE || echo BLOCKED"
}

tcp_result() {
  run_on_instance "$1" "timeout 5 curl -fsS --connect-timeout 5 telnet://$2:$3 >/dev/null 2>&1 && echo REACHABLE || echo BLOCKED"
}

check() {
  local label="$1" output="$2" expected="$3"
  if grep -q "$expected" <<<"$output"; then
    echo "PASS | $label"
  else
    echo "FAIL | $label | expected $expected | got: $output"
    return 1
  fi
}

check_packet_counter() {
  local label="$1" output="$2" packets
  packets=$(awk '/dpt:8443/ { print $1; exit }' <<<"$output")

  if [[ "$packets" =~ ^[1-9][0-9]*$ ]]; then
    echo "PASS | $label | packets: $packets"
  else
    echo "FAIL | $label | expected packet count > 0 | got: ${packets:-no matching rule}"
    return 1
  fi
}

{
  echo "========================================================"
  echo "Hub-and-Spoke — AWS Validation Matrix"
  echo "========================================================"
}

status=0
check "Spoke1 local TCP/8443 test service is healthy" \
  "$(local_service_result "$SPOKE1_ID")" \
  "REACHABLE" || status=1
check "Spoke2 local TCP/8443 test service is healthy" \
  "$(local_service_result "$SPOKE2_ID")" \
  "REACHABLE" || status=1
check "Spoke1 -> Spoke2 TCP/8443 is allowed" \
  "$(http_result "$SPOKE1_ID" "$SPOKE2_IP")" \
  "REACHABLE" || status=1
check "Spoke2 -> Spoke1 TCP/8443 is denied" \
  "$(http_result "$SPOKE2_ID" "$SPOKE1_IP")" \
  "BLOCKED" || status=1
check "Spoke1 -> NVA TCP/22 is denied" \
  "$(tcp_result "$SPOKE1_ID" "$NVA_IP" 22)" \
  "BLOCKED" || status=1
check_packet_counter "NVA records forwarded TCP/8443 traffic" \
  "$(run_on_instance "$NVA_ID" "sudo iptables -nvL FORWARD")" || status=1

exit "$status"
