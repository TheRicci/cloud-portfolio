# Run 02-iam-oidc Multi-Cloud or Cloud-Specific Verification Suite
param (
    [string]$Cloud = "all"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($Cloud.ToLower() -eq "aws") {
    & "$scriptDir\run-aws-tests.ps1"
} elseif ($Cloud.ToLower() -eq "azure") {
    & "$scriptDir\run-azure-tests.ps1"
} else {
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host " RUNNING FULL MULTI-CLOUD AUDIT SUITE (AWS & AZURE)" -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan
    & "$scriptDir\run-aws-tests.ps1"
    Write-Host ""
    & "$scriptDir\run-azure-tests.ps1"
}
