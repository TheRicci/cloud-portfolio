# IAM & OIDC Federation Security Audit & Proof Report

> **Audit Timestamp:** `2026-11-22T03:59:17Z`  
> **Audit Outcome:** `ALL INVARIANTS VERIFIED (PASS)`  

## 1. Automated Verification Checks

| Verification Check | Status | Details |
|---|:---:|---|
| `Terraform Formatting` | ✅ PASS | Consistent indentation and formatting |
| `TF Validate (bootstrap\aws)` | ✅ PASS | Provider syntax & schema valid |
| `TF Validate (bootstrap\azure)` | ✅ PASS | Provider syntax & schema valid |
| `TF Validate (aws)` | ✅ PASS | Provider syntax & schema valid |
| `TF Validate (azure)` | ✅ PASS | Provider syntax & schema valid |
| `OIDC Trust & Boundary Invariants` | ✅ PASS | 16/16 security tests passed |

## 2. Attack Vector & Negative Probe Verification

| ID | Cloud | Threat Scenario | Expected Defense | Verified Result |
|:---:|:---:|---|---|---|
| **P-01** | AWS | Pull Request trying to assume aws-apply role | `403 Forbidden` | ✅ `AccessDenied` (token.actions.githubusercontent.com:sub does ...) |
| **P-02** | AWS | Compromised apply role attempts to create unbounded admin role | `403 AccessDenied` | ✅ `AccessDenied` (iam:CreateRole denied by policy condition: ia...) |
| **P-03** | AWS | Compromised apply role attempts to delete OIDC provider or tamper with boundary | `403 ExplicitDeny` | ✅ `AccessDenied` (Explicit Deny statement DenyIdentityControlPl...) |
| **P-04** | Azure | Azure Contributor attempts to grant Owner role or assign permissions | `AuthorizationFailed` | ✅ `AuthorizationFailed` (The client does not have authorization to per...) |
| **P-05** | Azure | Feature branch job attempts to login to id-portfolio-apply without environment | `AADSTS70021` | ✅ `AADSTS70021` (No matching federated identity record found f...) |

## 3. Defense-in-Depth Proof Highlights

1. **Zero Long-Lived Secrets:** No static AWS Access Keys or Azure Client Secrets stored in repository or CI.
2. **Exact Subject Locking:** Wildcard claims (`repo:org/*`) are strictly rejected. Only exact environments and branch hashes can assume roles.
3. **Role Separation (Plan vs Apply):** Plan identity has read-only access to infrastructure + lock file access. Apply identity runs only after GitHub Environment approval.
4. **Permission Boundary Blast Radius Control:** In AWS, any role created by the apply identity must have `portfolio-boundary` attached; tampering with the boundary or OIDC provider is explicitly denied. In Azure, identity is scoped as `Contributor` on the Resource Group with zero role assignment capabilities.
