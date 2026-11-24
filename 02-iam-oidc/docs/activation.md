# Activation Checklist & Live Runbook

This guide details the step-by-step procedure to provision and activate OIDC Federation on AWS and Azure.

---

## 1. Configure GitHub Environments

Navigate to **GitHub Repository → Settings → Environments** and create four environments:
1. `aws-plan`
2. `aws-apply`
3. `azure-plan`
4. `azure-apply`

### Protection Rules
- **Apply Environments (`aws-apply`, `azure-apply`):**
  - **Deployment branches:** Selected branches only → `main`.
  - **Required reviewers:** Enabled (specify yourself or team lead).
  - **Wait timer:** Optional (e.g., 0 minutes).
- **Plan Environments (`aws-plan`, `azure-plan`):**
  - No required reviewers (runs automatically on Pull Requests).
  - No deployment branch restrictions (accessible by PRs).

---

## 2. Observe Real Claims Before Applying Trust

GitHub OIDC tokens generate a `sub` (subject) claim formatted based on the context:
- For an environment: `repo:<org>/<repo>:environment:<environment-name>`
- For a branch without environment: `repo:<org>/<repo>:ref:refs/heads/<branch>`
- For a pull request: `repo:<org>/<repo>:pull_request`

Record the exact non-secret `sub` claims into [trust-claims.md](trust-claims.md). Use these observed values in your `terraform.tfvars` files.

---

## 3. Bootstrap Remote State Storage Locally

> **Important:** Identity roots and state storage are applied locally using a human admin session with MFA. CI must never manage its own identity infrastructure.

### AWS State Bootstrap
```bash
cd 02-iam-oidc/bootstrap/aws
cp terraform.tfvars.example terraform.tfvars

# Set region and a globally unique state_bucket_name
terraform init
terraform plan
terraform apply
```

### Azure State Bootstrap
```bash
cd 02-iam-oidc/bootstrap/azure
cp terraform.tfvars.example terraform.tfvars

# Set location, resource_group_name, and storage_account_name
terraform init
terraform plan
terraform apply
```

---

## 4. Deploy Identity Roots Locally

### AWS Identity Deployment
```bash
cd 02-iam-oidc/aws
cp terraform.tfvars.example terraform.tfvars

# Populate:
# - region
# - state_bucket_name (from bootstrap output)
# - github_subject_plan  (e.g., repo:owner/cloud-portfolio:environment:aws-plan)
# - github_subject_apply (e.g., repo:owner/cloud-portfolio:environment:aws-apply)

terraform init
terraform plan
terraform apply
```

Outputs generated:
- `plan_role_arn`
- `apply_role_arn`
- `permission_boundary_arn`

### Azure Identity Deployment
```bash
cd 02-iam-oidc/azure
cp terraform.tfvars.example terraform.tfvars

# Populate:
# - deployment_resource_group_id
# - state_resource_group_name
# - state_storage_account_name
# - github_subject_plan  (e.g., repo:owner/cloud-portfolio:environment:azure-plan)
# - github_subject_apply (e.g., repo:owner/cloud-portfolio:environment:azure-apply)

terraform init
terraform plan
terraform apply
```

Outputs generated:
- `plan_client_id`
- `apply_client_id`
- `tenant_id`
- `subscription_id`

---

## 5. Add Non-Secret Environment Variables to GitHub

In **GitHub → Settings → Environments**, add the output identifiers as **Environment Variables** (these are public identifiers, not secrets):

| Environment | Environment Variables |
|---|---|
| `aws-plan` | `AWS_REGION`, `AWS_PLAN_ROLE_ARN` |
| `aws-apply` | `AWS_REGION`, `AWS_APPLY_ROLE_ARN` |
| `azure-plan` | `AZURE_PLAN_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| `azure-apply` | `AZURE_APPLY_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |

---

## 6. Run Automated Verification & Probes

Run the automated test runner to produce fresh verification evidence:

```bash
# From the repository root or 02-iam-oidc/
python 02-iam-oidc/tests/run_tests.py
```

The script will validate configurations, check all 16 security invariants, execute negative attack vector simulations, and output verified proof to `02-iam-oidc/tests/results/`.
