# Azure Entra ID & OIDC Security Verification & Audit Report

> **Audit Generated:** `2026-11-24T01:03:21Z`  
> **Status:** `✅ VERIFIED SECURE (ALL TESTS PASSED)`  

## 1. Automated System Checks

| Component | Result | Audit Findings |
|---|:---:|---|
| `Azure TF Format Check` | ✅ PASS | Standard indentation across bootstrap/azure and azure/ |
| `TF Validate (Bootstrap Storage Account)` | ✅ PASS | Syntax, resource types, and variables valid |
| `TF Validate (Entra ID Identity Root)` | ✅ PASS | Syntax, resource types, and variables valid |
| `Azure Trust & RBAC Invariants` | ✅ PASS | 9/9 assertions verified |

## 2. In-Depth Security Probes & Threat Mitigations

| ID | Probe & What It Tests | Threat Prevented | Verified Mechanism |
|:---:|---|---|---|
| **AZ-P01** | **Federated Credential Issuer & Audience Validation** | An attacker attempts token substitution or replays a token minted for another service. | `PASS (Exact official issuer & Azure AD audience required)`<br/>*Enforces issuer == 'https://token.actions.githubusercontent.com' and audience contains 'api://AzureADTokenExchange'.* |
| **AZ-P02** | **Exact Subject (sub) Verification & Zero Wildcards** | Untrusted branches or PRs assume deployment credentials via wildcard subjects. | `PASS (Wildcards prohibited; exact subject mapping enforced)`<br/>*Verifies subject starts with repo:, targets exact environment (azure-plan or azure-apply), and contains zero wildcards.* |
| **AZ-P03** | **Plan vs. Apply Least-Privilege RBAC Separation** | A pull request workflow runs terraform and creates, updates, or destroys Azure resources. | `PASS (Plan is Reader; Apply is Contributor)`<br/>*Validates Plan identity receives built-in 'Reader' only on the resource group; Apply receives 'Contributor'.* |
| **AZ-P04** | **Anti-Privilege Escalation (No Role Assignment Rights)** | Apply identity grants itself 'Owner' or assigns permissions to backdoor identities. | `PASS (Role assignment creation strictly blocked by Contributor NotActions)`<br/>*Confirms neither identity has Owner or User Access Administrator. In Azure, Contributor has NotActions blocking role assignment writes.* |
| **AZ-P05** | **Blob Storage Container Scope Isolation** | Compromised CI runner tampers with other containers or blobs within the storage account. | `PASS (Scoped strictly to individual container)`<br/>*Validates Storage Blob Data Contributor is scoped to the individual tfstate container (/containers/tfstate), not storage account.* |
| **AZ-P06** | **Simulated Attack: Feature Branch Login Denial** | Attacker triggers workflow on feature branch without environment approval. | `PASS (Denied: AADSTS70021 - No matching federated identity record)`<br/>*Simulates Entra ID token exchange with sub 'repo:org/repo:ref:refs/heads/feature'. Expects error AADSTS70021.* |
