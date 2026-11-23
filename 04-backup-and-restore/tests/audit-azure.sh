#!/usr/bin/env bash
# Runs Azure leftover audit.
set -Eeuo pipefail
exec bash "$(dirname "$0")/azure/audit.sh" "$@"
