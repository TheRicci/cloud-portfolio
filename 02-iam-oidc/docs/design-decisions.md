# Architecture & Security Design Decisions

This document details the fundamental architectural decisions and trade-offs chosen in this project.

---

## 1. Separate Plan and Apply Identities

### Decision
Terraform planning and terraform application use two distinct cloud identities (`portfolio-gh-plan` and `portfolio-gh-apply` in AWS; `id-portfolio-plan` and `id-portfolio-apply` in Azure).

### Why
- Pull requests are open to contributors and automated bots. If a PR workflow runs with write permissions, malicious code in a PR could destroy or alter production resources.
- Separating identities ensures that PR workflows can only inspect state and plan changes. Production mutations can only occur when the workflow is manually approved and runs inside the protected apply environment.

---

## 2. No CI Control Over Identity Infrastructure

### Decision
All identity roots (`aws/` and `azure/`) and state backends (`bootstrap/`) are provisioned locally by a human administrator authenticated via MFA. CI is never given access to run Terraform against `aws/`, `azure/`, or `bootstrap/`.

### Why
If CI had permission to manage its own IAM roles or federated credentials, a compromised CI job could simply grant itself `AdministratorAccess` or remove its permission boundary. Keeping identity management outside CI maintains an immutable trust anchor.

---

## 3. Remote State Access Is Scoped, Not Read-Only

### Decision
Both Plan and Apply identities are granted data-plane read/write permissions to their specific remote state object/container.

### Why
Many teams mistakenly assume `terraform plan` is a read-only operation. In reality:
1. Terraform remote backends require acquiring and releasing a state lock (e.g. S3 `.tflock` or Azure Blob lease) even during planning to prevent race conditions.
2. Terraform may refresh and persist provider state changes.
Therefore, the plan identity must be given tightly scoped read/write access to the state key/container only, rather than broad bucket access.

---

## 4. Azure App Registrations vs. User-Assigned Managed Identities

### Decision
We use Entra ID App Registrations with Federated Identity Credentials rather than User-Assigned Managed Identities (UAMI).

### Why
- Both support workload identity federation.
- App Registrations and their federated credentials can be provisioned and inspected cleanly via Terraform's `azuread` provider without requiring subscription-level managed identity operators.
- The separation between the Application (identity definition) and Service Principal (local tenant instantiation) provides clear auditing in Entra ID sign-in logs.
