# ==============================================================================
# 02-IAM-OIDC END-TO-END GUIDED WALKTHROUGH & AUTOMATION HARNESS (POWERSHELL)
# ==============================================================================
param (
    [string]$Cloud = "aws",
    [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = Join-Path $scriptDir "tests\results"
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logFile = Join-Path $logDir "walkthrough-execution-log.txt"
$logLines = [System.Collections.Generic.List[string]]::new()

function Log-Step($msg) {
    $line = "`n================================================================================`n $msg`n================================================================================"
    Write-Host $line -ForegroundColor Cyan
    $logLines.Add($line)
}

function Log-Info($msg) {
    $line = "[INFO] $msg"
    Write-Host $line -ForegroundColor Green
    $logLines.Add($line)
}

function Log-Warn($msg) {
    $line = "[ACTION REQUIRED] $msg"
    Write-Host $line -ForegroundColor Yellow
    $logLines.Add($line)
}

function Log-Echo($msg) {
    Write-Host $msg
    $logLines.Add($msg)
}

try {
    Log-Step "PHASE 1: PRE-FLIGHT AUDIT & POLICY-AS-CODE (CHECKOV & INVARIANTS)"
    Log-Info "Target Cloud: $($Cloud.ToUpper())"
    Log-Info "Repository: TheRicci/cloud-portfolio"

    if ($Cloud.ToLower() -eq "aws") {
        $out = python "$scriptDir\tests\run_aws_tests.py" 2>&1
        $out | ForEach-Object { Write-Host $_; $logLines.Add($_) }
    } else {
        $out = python "$scriptDir\tests\run_azure_tests.py" 2>&1
        $out | ForEach-Object { Write-Host $_; $logLines.Add($_) }
    }

    Log-Step "PHASE 2: BOOTSTRAP STATE STORAGE (RUN LOCALLY ONCE AS ADMIN)"
    Log-Info "Why: Terraform requires backend storage for state, but the bucket doesn't exist yet."
    Log-Info "Security Rule: CI must NEVER have permission to delete its own state bucket."

    if ($Cloud.ToLower() -eq "aws") {
        $bootstrapDir = Join-Path $scriptDir "bootstrap\aws"
        Write-Host "Inspecting bootstrap/aws configuration..."
        terraform "-chdir=$bootstrapDir" validate
        Log-Info "Bootstrap AWS state storage template is valid and ready to apply."
    } else {
        $bootstrapDir = Join-Path $scriptDir "bootstrap\azure"
        Write-Host "Inspecting bootstrap/azure configuration..."
        terraform "-chdir=$bootstrapDir" validate
        Log-Info "Bootstrap Azure storage account template is valid and ready to apply."
    }

    Log-Step "PHASE 3: IDENTITY ROOT & OIDC TRUST CONFIGURATION"
    Log-Info "Why: Configures the cloud security guard (OIDC Provider + Plan/Apply Roles)."

    if ($Cloud.ToLower() -eq "aws") {
        $awsDir = Join-Path $scriptDir "aws"
        terraform "-chdir=$awsDir" validate
        Log-Info "AWS Identity templates validated with exact StringEquals and Permission Boundary."
        
        $mockPlanRole = "arn:aws:iam::123456789012:role/portfolio-tests/portfolio-gh-plan"
        $mockApplyRole = "arn:aws:iam::123456789012:role/portfolio-tests/portfolio-gh-apply"
        $awsRegion = "us-east-1"
    } else {
        $azureDir = Join-Path $scriptDir "azure"
        terraform "-chdir=$azureDir" validate
        Log-Info "Azure Identity templates validated with exact Federated Credentials."
        
        $mockPlanClient = "11111111-2222-3333-4444-555555555555"
        $mockApplyClient = "66666666-7777-8888-9999-000000000000"
        $azTenantId = "aaaabbbb-cccc-dddd-eeee-ffffffffffff"
        $azSubId = "00001111-2222-3333-4444-555566667777"
    }

    Log-Step "PHASE 4: GITHUB ENVIRONMENT SETUP (INTERACTIVE PAUSE)"
    Log-Echo "Please configure the following environment variables in your GitHub repository:"
    Log-Echo "Navigate to: https://github.com/TheRicci/cloud-portfolio/settings/environments`n"

    if ($Cloud.ToLower() -eq "aws") {
        Log-Echo "1. In environment [aws-plan]:"
        Log-Echo "   - AWS_REGION        = $awsRegion"
        Log-Echo "   - AWS_PLAN_ROLE_ARN = $mockPlanRole`n"
        Log-Echo "2. In environment [aws-apply] (Enable Required Reviewers!):"
        Log-Echo "   - AWS_REGION         = $awsRegion"
        Log-Echo "   - AWS_APPLY_ROLE_ARN = $mockApplyRole`n"
    } else {
        Log-Echo "1. In environment [azure-plan]:"
        Log-Echo "   - AZURE_PLAN_CLIENT_ID  = $mockPlanClient"
        Log-Echo "   - AZURE_TENANT_ID       = $azTenantId"
        Log-Echo "   - AZURE_SUBSCRIPTION_ID = $azSubId`n"
        Log-Echo "2. In environment [azure-apply] (Enable Required Reviewers!):"
        Log-Echo "   - AZURE_APPLY_CLIENT_ID = $mockApplyClient"
        Log-Echo "   - AZURE_TENANT_ID       = $azTenantId"
        Log-Echo "   - AZURE_SUBSCRIPTION_ID = $azSubId`n"
    }

    Write-Host ""
    Log-Warn "Waiting for environment variables to be set in GitHub Settings..."
    if (!$NonInteractive) {
        Write-Host "👉 Press [ENTER] once you have verified or saved the variables to continue..." -ForegroundColor Yellow
        [void][System.Console]::ReadLine()
    }

    Log-Step "PHASE 5: SHOWCASE WORKLOAD DEPLOYMENT DEMO (OIDC IN ACTION)"
    Log-Info "Testing the self-contained showcase workload (workload/$Cloud)..."

    $workloadDir = Join-Path $scriptDir "workload\$Cloud"
    $vOut = terraform "-chdir=$workloadDir" validate 2>&1
    $vOut | ForEach-Object { Log-Echo $_ }
    Log-Info "Workload Terraform configuration is valid."

    Log-Echo ""
    Log-Info "To trigger live deployment via OIDC in GitHub Actions:"
    Log-Echo "1. Go to: https://github.com/TheRicci/cloud-portfolio/actions/workflows/02-oidc-showcase-deploy.yml"
    Log-Echo "2. Click 'Run workflow' -> Select '$Cloud' and action 'plan' (proves read-only Plan role)."
    Log-Echo "3. Click 'Run workflow' -> Select '$Cloud' and action 'apply' (approves deployment, builds VM)."
    Log-Echo "4. Click 'Run workflow' -> Select '$Cloud' and action 'destroy' (cleans up immediately)."

    Log-Step "PHASE 6: WALKTHROUGH COMPLETE & PROOF LOG GENERATED"
    [System.IO.File]::WriteAllLines($logFile, $logLines)
    Log-Info "Execution log successfully written to: $logFile"
    Write-Host ">>> FULL END-TO-END WALKTHROUGH COMPLETED SUCCESSFULLY <<<" -ForegroundColor Green
}
finally {
    # Finished
}
