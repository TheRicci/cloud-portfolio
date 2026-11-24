# Showcase Workload: End-to-End OIDC Deployment Demo

This directory contains a self-contained, minimal workload designed specifically to **showcase and prove end-to-end OIDC authentication within this project itself**, without needing to touch any other repository or project.

---

## What It Deploys

| Cloud | Showcase Infrastructure | Cost | Proof Generated |
|---|---|---|---|
| **AWS** (`workload/aws`) | Minimal VPC + Subnet + Security Group + **`t3.nano` EC2 VM** | ~\$0.005 / hour | Outputs EC2 instance ID, private IP, and the exact IAM Caller Identity ARN (`portfolio-gh-apply`) proving it was deployed via OIDC. |
| **Azure** (`workload/azure`) | Minimal VNet + Subnet + NIC + **`Standard_B1s` Linux VM** | ~\$0.010 / hour | Outputs Azure VM ID, private IP, and the exact Entra ID Service Principal Client ID proving federated token exchange. |

> **Cost Safety:** These workloads are ultra-lightweight. They are meant to be deployed for a 5-minute demonstration and immediately destroyed using `terraform destroy` or the GitHub Actions cleanup job.

---

## How It Proves the OIDC Architecture

```
                                  [ Pull Request ]
                                         │
                                         ▼
                     GitHub Actions requests temporary credentials
                       using subject: repo:org/repo:pull_request
                                         │
                                         ▼
                                   [ Cloud STS ]
                         Issues PLAN Role (Read-Only)
                                         │
                                         ▼
                       Runs "terraform plan" successfully!
                    (Blocked if it tries to modify or destroy)
                                         │
                                  [ PR Merged / Approved ]
                                         │
                                         ▼
                     GitHub Actions requests temporary credentials
                   using subject: repo:org/repo:environment:aws-apply
                                         │
                                         ▼
                                   [ Cloud STS ]
                         Issues APPLY Role (Write Access)
                                         │
                                         ▼
                      Runs "terraform apply -auto-approve"
                    Deploys the Showcase VM with Zero Keys!
                                         │
                                         ▼
                     CloudTrail / Activity Log records session
                       as: gh-<run-id> with 15-min expiration!
```

---

## How to Test It

### Method 1: Automated via GitHub Actions (Recommended)

1. Open your repository on GitHub and navigate to the **Actions** tab.
2. Select the workflow: **`02 — OIDC Showcase Workload Deploy & Destroy`**.
3. Click **Run workflow**:
   - **Target Cloud:** `aws`, `azure`, or `both`.
   - **Action:**
     - `plan`: Runs under `aws-plan` / `azure-plan` environment to verify read-only planning.
     - `apply`: Runs under protected `aws-apply` / `azure-apply` environment (requires approval), deploys the VM, and outputs proof.
     - `destroy`: Tears down the VM and network resources cleanly so there is zero ongoing cost.

### Method 2: Locally on Your Machine

You can also plan or run the showcase workload locally with your own admin credentials:

```bash
# AWS:
cd 02-iam-oidc/workload/aws
terraform plan
# Apply only if you wish to run a live test:
# terraform apply
# terraform destroy

# Azure:
cd 02-iam-oidc/workload/azure
terraform plan
# terraform apply
# terraform destroy
```
