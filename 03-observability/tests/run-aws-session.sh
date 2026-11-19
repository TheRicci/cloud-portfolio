#!/usr/bin/env bash
# Runs the AWS session only. Set the AWS workload and monitoring VM variables first.
set -Eeuo pipefail
CLOUDS=aws exec bash "$(dirname "$0")/run-session.sh"

