# Run Azure OIDC Federation Security Audit & Proof Suite
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Running Azure OIDC Federation Security Audit & Proof Suite..." -ForegroundColor Cyan
python "$scriptDir\tests\run_azure_tests.py"
