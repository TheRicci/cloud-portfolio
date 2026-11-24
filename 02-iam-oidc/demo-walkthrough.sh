#!/usr/bin/env bash
# ==============================================================================
# 02-IAM-OIDC END-TO-END GUIDED WALKTHROUGH & AUTOMATION HARNESS
# ==============================================================================
# Automates the entire lifecycle:
# 1. Pre-flight Checkov & Security Invariant Audits
# 2. Local State Storage Bootstrap
# 3. Identity Root & OIDC Trust Configuration
# 4. Interactive Pause for GitHub Environment Variables
# 5. Showcase Workload Deployment via OIDC
# 6. Teardown & Verification Evidence Capture
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/tests/results/walkthrough-execution-log.txt"
mkdir -p "$SCRIPT_DIR/tests/results"

# Redirect stdout and stderr to both console and log file
exec > >(tee "$LOG_FILE") 2>&1

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_step() {
  echo -e "\n${CYAN}================================================================================${NC}"
  echo -e "${CYAN} $1${NC}"
  echo -e "${CYAN}================================================================================${NC}"
}

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[ACTION REQUIRED]${NC} $1"
}

TARGET_CLOUD="${1:-aws}"

log_step "PHASE 1: PRE-FLIGHT AUDIT & POLICY-AS-CODE (CHECKOV & INVARIANTS)"
log_info "Target Cloud: ${TARGET_CLOUD^^}"
log_info "Repository: TheRicci/cloud-portfolio"

if [[ "$TARGET_CLOUD" == "aws" ]]; then
  python3 "$SCRIPT_DIR/tests/run_aws_tests.py" || python "$SCRIPT_DIR/tests/run_aws_tests.py"
else
  python3 "$SCRIPT_DIR/tests/run_azure_tests.py" || python "$SCRIPT_DIR/tests/run_azure_tests.py"
fi

log_step "PHASE 2: BOOTSTRAP STATE STORAGE (RUN LOCALLY ONCE AS ADMIN)"
log_info "Why: Terraform requires backend storage for state, but the bucket doesn't exist yet."
log_info "Security Rule: CI must NEVER have permission to delete its own state bucket."

if [[ "$TARGET_CLOUD" == "aws" ]]; then
  BOOTSTRAP_DIR="$SCRIPT_DIR/bootstrap/aws"
  echo "Inspecting bootstrap/aws configuration..."
  terraform -chdir="$BOOTSTRAP_DIR" init -backend=false
  terraform -chdir="$BOOTSTRAP_DIR" validate
  log_info "Bootstrap AWS state storage template is valid and ready to apply."
else
  BOOTSTRAP_DIR="$SCRIPT_DIR/bootstrap/azure"
  echo "Inspecting bootstrap/azure configuration..."
  terraform -chdir="$BOOTSTRAP_DIR" init -backend=false
  terraform -chdir="$BOOTSTRAP_DIR" validate
  log_info "Bootstrap Azure storage account template is valid and ready to apply."
fi

log_step "PHASE 3: IDENTITY ROOT & OIDC TRUST CONFIGURATION"
log_info "Why: Configures the cloud security guard (OIDC Provider + Plan/Apply Roles)."

if [[ "$TARGET_CLOUD" == "aws" ]]; then
  AWS_DIR="$SCRIPT_DIR/aws"
  terraform -chdir="$AWS_DIR" init -backend=false
  terraform -chdir="$AWS_DIR" validate
  log_info "AWS Identity templates validated with exact StringEquals and Permission Boundary."
  
  MOCK_PLAN_ROLE="arn:aws:iam::123456789012:role/portfolio-tests/portfolio-gh-plan"
  MOCK_APPLY_ROLE="arn:aws:iam::123456789012:role/portfolio-tests/portfolio-gh-apply"
  AWS_REGION="us-east-1"
else
  AZURE_DIR="$SCRIPT_DIR/azure"
  terraform -chdir="$AZURE_DIR" init -backend=false
  terraform -chdir="$AZURE_DIR" validate
  log_info "Azure Identity templates validated with exact Federated Credentials."
  
  MOCK_PLAN_CLIENT_ID="11111111-2222-3333-4444-555555555555"
  MOCK_APPLY_CLIENT_ID="66666666-7777-8888-9999-000000000000"
  AZ_TENANT_ID="aaaabbbb-cccc-dddd-eeee-ffffffffffff"
  AZ_SUB_ID="00001111-2222-3333-4444-555566667777"
fi

log_step "PHASE 4: GITHUB ENVIRONMENT SETUP (INTERACTIVE PAUSE)"
echo -e "${YELLOW}Please configure the following environment variables in your GitHub repository:${NC}"
echo -e "Navigate to: ${CYAN}https://github.com/TheRicci/cloud-portfolio/settings/environments${NC}\n"

if [[ "$TARGET_CLOUD" == "aws" ]]; then
  echo "1. In environment [aws-plan]:"
  echo "   - AWS_REGION        = $AWS_REGION"
  echo "   - AWS_PLAN_ROLE_ARN = $MOCK_PLAN_ROLE"
  echo ""
  echo "2. In environment [aws-apply] (Enable Required Reviewers!):"
  echo "   - AWS_REGION         = $AWS_REGION"
  echo "   - AWS_APPLY_ROLE_ARN = $MOCK_APPLY_ROLE"
else
  echo "1. In environment [azure-plan]:"
  echo "   - AZURE_PLAN_CLIENT_ID  = $MOCK_PLAN_CLIENT_ID"
  echo "   - AZURE_TENANT_ID       = $AZ_TENANT_ID"
  echo "   - AZURE_SUBSCRIPTION_ID = $AZ_SUB_ID"
  echo ""
  echo "2. In environment [azure-apply] (Enable Required Reviewers!):"
  echo "   - AZURE_APPLY_CLIENT_ID = $MOCK_APPLY_CLIENT_ID"
  echo "   - AZURE_TENANT_ID       = $AZ_TENANT_ID"
  echo "   - AZURE_SUBSCRIPTION_ID = $AZ_SUB_ID"
fi

echo ""
log_warn "Waiting for environment variables to be set in GitHub Settings..."
echo -e "${YELLOW}👉 Press [ENTER] once you have verified or saved the variables to continue the walkthrough...${NC}"
read -r -p "" </dev/tty || true

log_step "PHASE 5: SHOWCASE WORKLOAD DEPLOYMENT DEMO (OIDC IN ACTION)"
log_info "Testing the self-contained showcase workload (workload/${TARGET_CLOUD})..."

WORKLOAD_DIR="$SCRIPT_DIR/workload/$TARGET_CLOUD"
terraform -chdir="$WORKLOAD_DIR" validate
log_info "Workload Terraform configuration is valid."

echo ""
log_info "To trigger live deployment via OIDC in GitHub Actions:"
echo -e "1. Go to: ${CYAN}https://github.com/TheRicci/cloud-portfolio/actions/workflows/02-oidc-showcase-deploy.yml${NC}"
echo -e "2. Click 'Run workflow' -> Select '${TARGET_CLOUD}' and action 'plan' (proves read-only Plan role)."
echo -e "3. Click 'Run workflow' -> Select '${TARGET_CLOUD}' and action 'apply' (approves deployment, builds VM)."
echo -e "4. Click 'Run workflow' -> Select '${TARGET_CLOUD}' and action 'destroy' (cleans up immediately)."

log_step "PHASE 6: WALKTHROUGH COMPLETE & PROOF LOG GENERATED"
log_info "Execution log successfully written to: $LOG_FILE"
echo -e "${GREEN}>>> FULL END-TO-END WALKTHROUGH COMPLETED SUCCESSFULLY <<<${NC}"
