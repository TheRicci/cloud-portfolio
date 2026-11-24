# AWS IAM & OIDC Security Verification & Audit Report

> **Audit Generated:** `2026-11-24T01:12:05Z`  
> **Status:** `✅ VERIFIED SECURE (ALL TESTS PASSED)`  

## 1. Automated System Checks

| Component | Result | Audit Findings |
|---|:---:|---|
| `AWS TF Format Check` | ✅ PASS | Standard indentation across bootstrap/aws and aws/ |
| `TF Validate (Bootstrap S3 State)` | ✅ PASS | Syntax, resource types, and variables valid |
| `TF Validate (IAM Identity Root)` | ✅ PASS | Syntax, resource types, and variables valid |
| `AWS Trust & Boundary Invariants` | ✅ PASS | 11/11 assertions verified |

## 2. In-Depth Security Probes & Threat Mitigations

| ID | Probe & What It Tests | Threat Prevented | Verified Mechanism |
|:---:|---|---|---|
| **AWS-P01** | **Strict Subject (sub) Locking & Wildcard Rejection** | An attacker creates a feature branch or PR hoping to assume the deployment role. | `PASS (Wildcard rejected; StringEquals enforced)`<br/>*Evaluates condition operator. Rejects StringLike/wildcards; enforces StringEquals on repo:org/repo:environment:aws-apply.* |
| **AWS-P02** | **Exact Audience (aud) STS Validation** | Token minted for a third-party service is replayed to AWS STS. | `PASS (sts.amazonaws.com strictly required)`<br/>*Assumes role trust policy requires token.actions.githubusercontent.com:aud == 'sts.amazonaws.com'.* |
| **AWS-P03** | **Plan vs. Apply Least-Privilege Separation** | An unvetted pull request runs terraform plan and mutates cloud infrastructure. | `PASS (Plan has zero mutation rights)`<br/>*Confirms portfolio-gh-plan role has zero mutation policies attached (read/lock only).* |
| **AWS-P04** | **S3 Remote State Blast Radius Scoping** | Compromised CI runner accesses state files of other applications in the same S3 bucket. | `PASS (Access scoped strictly to 02-iam-oidc state prefix)`<br/>*Validates s3:prefix condition on s3:ListBucket and locks Get/Put/Delete to exact state key & .tflock.* |
| **AWS-P05** | **Permission Boundary Ceiling (Anti-Privilege Escalation)** | Apply role creates child IAM roles with AdministratorAccess to take over the account. | `PASS (Boundary inheritance strictly enforced; unconstrained role creation blocked)`<br/>*Asserts apply role has boundary attached and requires any created role to inherit portfolio-boundary.* |
| **AWS-P06** | **Identity Control Plane Anti-Tamper Protection** | Apply role deletes the OIDC provider or modifies assume_role_policy to remove restrictions. | `PASS (Tampering blocked by explicit Deny)`<br/>*Validates explicit Deny statements on DeleteOpenIDConnectProvider and UpdateAssumeRolePolicy.* |
