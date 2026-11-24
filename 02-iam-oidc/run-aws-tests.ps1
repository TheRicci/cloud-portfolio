# Run AWS OIDC Federation Security Audit & Proof Suite
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Running AWS OIDC Federation Security Audit & Proof Suite..." -ForegroundColor Cyan
python "$scriptDir\tests\run_aws_tests.py"
