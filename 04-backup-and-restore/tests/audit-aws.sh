#!/usr/bin/env bash
# Runs AWS leftover audit.
set -Eeuo pipefail
exec bash "$(dirname "$0")/aws/audit.sh" "$@"
