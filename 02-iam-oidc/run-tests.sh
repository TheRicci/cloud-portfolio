#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-all}"

if [[ "$TARGET" == "aws" ]]; then
  bash "$SCRIPT_DIR/run-aws-tests.sh"
elif [[ "$TARGET" == "azure" ]]; then
  bash "$SCRIPT_DIR/run-azure-tests.sh"
else
  echo "================================================================================"
  echo " RUNNING FULL MULTI-CLOUD AUDIT SUITE (AWS & AZURE)"
  echo "================================================================================"
  bash "$SCRIPT_DIR/run-aws-tests.sh"
  echo ""
  bash "$SCRIPT_DIR/run-azure-tests.sh"
fi
