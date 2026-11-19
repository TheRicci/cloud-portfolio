#!/usr/bin/env bash
# Runs the Azure session only. Set the Azure and Grafana environment variables first.
set -Eeuo pipefail
CLOUDS=azure exec bash "$(dirname "$0")/run-session.sh"

