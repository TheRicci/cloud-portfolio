# Live Security Probes & Verification Runbook

This runbook contains the exact verification probes executed in live AWS and Azure environments. Every test is designed to verify either an **authorized path** or prove a **denied attack vector**.

---

## Allowed Paths (Proving Legitimate Workflows Succeed)

### AWS Live Verification
1. **Plan Identity Probe:**
   Trigger a workflow job inside the `aws-plan` environment:
   ```bash
   aws sts get-caller-identity
   ```
   **Expected Response:**
   ```json
   {
     "UserId": "AROA...:GitHubActions",
     "Account": "123456789012",
     "Arn": "arn:aws:iam::123456789012:role/portfolio-tests/portfolio-gh-plan"
   }
   ```

2. **Apply Identity Probe:**
   Trigger a workflow job inside the protected `aws-apply` environment after manual approval:
   ```bash
   aws sts get-caller-identity
   ```
   **Expected Response:**
   Arn indicates `portfolio-gh-apply`. CloudTrail logs the event under event name `AssumeRoleWithWebIdentity` with session name `gh-<run-id>`.

### Azure Live Verification
1. **Plan & Apply Identity Probes:**
   Trigger workflow jobs inside `azure-plan` and `azure-apply`:
   ```bash
   az account show
   ```
   **Expected Response:**
   Authenticated via Service Principal Client ID (`id-portfolio-plan` or `id-portfolio-apply`). Entra ID Sign-in Logs confirm successful federated token exchange.

---

## Denied Paths (Proving Attack Vectors Are Blocked)

### Probe D-01: PR Job Attempts to Assume Apply Role
- **Action:** A pull request workflow attempts to assume `portfolio-gh-apply`.
- **Expected Error:**
  ```text
  An error occurred (AccessDenied) when calling the AssumeRoleWithWebIdentity operation:
  Not authorized to perform sts:AssumeRoleWithWebIdentity (token subject does not match trust policy condition)
  ```

### Probe D-02: Workflow Without Environment Attempts Apply Identity
- **Action:** A workflow job running on a feature branch without entering the `aws-apply` environment attempts role assumption.
- **Expected Error:**
  `AccessDenied` because GitHub sends `sub: repo:org/repo:ref:refs/heads/feature`, which fails the strict `StringEquals` check against `environment:aws-apply`.

### Probe D-03: Compromised Apply Role Attempts Unbounded Role Creation
- **Action:** Under the AWS apply role, execute:
  ```bash
  aws iam create-role --role-name rogue-admin --assume-role-policy-document file://trust.json
  ```
- **Expected Error:**
  ```text
  An error occurred (AccessDenied) when calling the CreateRole operation:
  User: arn:aws:sts::123456789012:assumed-role/portfolio-gh-apply/session is not authorized
  to perform: iam:CreateRole because no identity-based policy allows the action without
  iam:PermissionsBoundary condition matching portfolio-boundary.
  ```

### Probe D-04: Apply Role Attempts to Delete OIDC Provider
- **Action:** Under the AWS apply role, execute:
  ```bash
  aws iam delete-open-id-connect-provider --open-id-connect-provider-arn <arn>
  ```
- **Expected Error:**
  `AccessDenied` due to explicit deny statement `DenyIdentityControlPlaneMutation`.

### Probe D-05: Azure Contributor Attempts Privilege Escalation
- **Action:** Under `id-portfolio-apply`, execute:
  ```bash
  az role assignment create --assignee <id> --role "Owner" --scope /subscriptions/...
  ```
- **Expected Error:**
  ```text
  (AuthorizationFailed) The client does not have authorization to perform action
  'Microsoft.Authorization/roleAssignments/write' over scope.
  ```

---

## Recording Evidence

Redact sensitive IDs (Account IDs, Tenant IDs, Subscription IDs) and store evidence outputs under `tests/results/`.
