#!/usr/bin/env bash
# Runs the AWS backup and restore session with auto-detected outputs.
set -Eeuo pipefail
exec bash "$(dirname "$0")/aws/run.sh" "$@"
