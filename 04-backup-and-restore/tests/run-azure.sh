#!/usr/bin/env bash
# Runs the Azure backup and restore session with auto-detected outputs.
set -Eeuo pipefail
exec bash "$(dirname "$0")/azure/run.sh" "$@"
