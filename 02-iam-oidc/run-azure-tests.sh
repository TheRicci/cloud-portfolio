#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Running Azure OIDC Federation Security Audit & Proof Suite..."
python3 "$SCRIPT_DIR/tests/run_azure_tests.py" || python "$SCRIPT_DIR/tests/run_azure_tests.py"
