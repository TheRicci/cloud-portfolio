#!/usr/bin/env bash
# Azure validation matrix for the secure-by-default hub-and-spoke design.
# Usage: ./connectivity.sh <resource-group> <spoke1-vm> <spoke2-vm> <nva-vm>

set -euo pipefail

RG="${1:?Usage: $0 <resource-group> <spoke1-vm> <spoke2-vm> <nva-vm>}"
SPOKE1_VM="${2:?}"
SPOKE2_VM="${3:?}"
NVA_VM="${4:?}"
# Evidence is intentionally printed to the terminal. Save the complete output
# manually in ../evidence/ after reviewing it.

SPOKE1_IP="10.1.1.4"
SPOKE2_IP="10.2.1.4"
NVA_IP="10.0.1.4"
PASS=0
FAIL=0

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

run_on_vm() {
  az vm run-command invoke \
    --resource-group "$RG" --name "$1" --command-id RunShellScript \
    --scripts "$2" --query "value[0].message" --output tsv 2>/dev/null || echo "COMMAND_FAILED"
}

tcp_result() {
  run_on_vm "$1" "timeout 5 bash -c '</dev/tcp/$2/$3>' >/dev/null 2>&1 && echo REACHABLE || echo BLOCKED"
}

local_service_result() {
  run_on_vm "$1" "cloud-init status --wait >/dev/null 2>&1 && timeout 5 bash -c '</dev/tcp/127.0.0.1/8443>' >/dev/null 2>&1 && echo REACHABLE || echo BLOCKED"
}

check() {
  local label="$1" output="$2" expected="$3"
  if grep -q "$expected" <<<"$output"; then
    echo "PASS | $label"
    PASS=$((PASS + 1))
  else
    echo "FAIL | $label | expected $expected | got: $output"
    FAIL=$((FAIL + 1))
  fi
}

check_packet_counter() {
  local label="$1" output="$2" packets
  packets=$(awk '/dpt:8443/ { print $1; exit }' <<<"$output")

  if [[ "$packets" =~ ^[1-9][0-9]*$ ]]; then
    echo "PASS | $label | packets: $packets"
    PASS=$((PASS + 1))
  else
    echo "FAIL | $label | expected packet count > 0 | got: ${packets:-no matching rule}"
    FAIL=$((FAIL + 1))
  fi
}

{
  echo "========================================================"
  echo "Hub-and-Spoke — Azure Validation Matrix"
  echo "Started: $(timestamp)"
  echo "========================================================"
}

# Prove both local test services are healthy before interpreting a denied
# cross-spoke result as an intentional policy decision.
check "Spoke1 local TCP/8443 test service is healthy" \
  "$(local_service_result "$SPOKE1_VM")" "REACHABLE"
check "Spoke2 local TCP/8443 test service is healthy" \
  "$(local_service_result "$SPOKE2_VM")" "REACHABLE"

check "Spoke1 -> Spoke2 TCP/8443 is allowed" \
  "$(tcp_result "$SPOKE1_VM" "$SPOKE2_IP" 8443)" "REACHABLE"
check "Spoke2 -> Spoke1 TCP/8443 is denied" \
  "$(tcp_result "$SPOKE2_VM" "$SPOKE1_IP" 8443)" "BLOCKED"
check "Spoke1 -> Spoke2 TCP/22 is denied" \
  "$(tcp_result "$SPOKE1_VM" "$SPOKE2_IP" 22)" "BLOCKED"
check "Spoke1 -> NVA TCP/22 is denied" \
  "$(tcp_result "$SPOKE1_VM" "$NVA_IP" 22)" "BLOCKED"

COUNTERS="$(run_on_vm "$NVA_VM" "iptables -nvL FORWARD")"
check_packet_counter "NVA records forwarded TCP/8443 traffic" "$COUNTERS"

{
  echo ""
  echo "Passed: $PASS"
  echo "Failed: $FAIL"
  echo "Finished: $(timestamp)"
}

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
