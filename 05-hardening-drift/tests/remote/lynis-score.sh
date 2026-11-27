#!/usr/bin/env bash
# Run as root on the VM. Prints the Lynis hardening index and the suggestion IDs.
set -u
report="$(mktemp)"
lynis audit system --quick --no-colors --report-file "$report" >/dev/null 2>&1
echo "hardening_index=$(sed -n 's/^hardening_index=//p' "$report" | tail -1)"
echo "warnings=$(grep -c '^warning\[\]=' "$report")"
echo "suggestions=$(grep -c '^suggestion\[\]=' "$report")"
echo "--suggestions"
sed -n 's/^suggestion\[\]=\([^|]*\)|.*/\1/p' "$report" | sort
rm -f "$report"
