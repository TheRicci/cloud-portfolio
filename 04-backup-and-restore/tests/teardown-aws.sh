#!/usr/bin/env bash
# Runs AWS teardown and audit.
set -Eeuo pipefail
exec bash "$(dirname "$0")/aws/teardown.sh" "$@"
