#!/usr/bin/env bash
# Runs Azure teardown and audit (including soft-delete purge).
set -Eeuo pipefail
exec bash "$(dirname "$0")/azure/teardown.sh" "$@"
