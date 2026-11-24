# Observed OIDC Trust Claims Reference

When GitHub Actions requests an OIDC token, its Token Service cryptographically signs a JSON Web Token (JWT) populated with metadata describing the exact execution context.

---

## Anatomy of a GitHub OIDC Token Payload

Here is an example of the decoded claims present in a GitHub Actions OIDC token:

```json
{
  "iss": "https://token.actions.githubusercontent.com",
  "aud": "sts.amazonaws.com",
  "sub": "repo:riccigt/cloud-portfolio:environment:aws-apply",
  "repository": "riccigt/cloud-portfolio",
  "repository_owner": "riccigt",
  "actor": "riccigt",
  "workflow": "deploy.yml",
  "head_ref": "",
  "base_ref": "",
  "event_name": "workflow_dispatch",
  "ref": "refs/heads/main",
  "ref_type": "branch",
  "environment": "aws-apply"
}
```

---

## Claim Explanations

| Claim | Definition | Why It Matters for Security |
|---|---|---|
| `iss` | Issuer URL (`https://token.actions.githubusercontent.com`) | Guarantees the token was minted by GitHub's official token service |
| `aud` | Audience (`sts.amazonaws.com` or `api://AzureADTokenExchange`) | Identifies the intended recipient. AWS and Azure will reject tokens minted for other services |
| `sub` | Subject identifier (e.g., `repo:org/repo:environment:aws-apply`) | **The most critical claim.** Defines the exact repository and environment authorized to assume the role |
| `repository` | Organization/User and Repository name | Prevents other GitHub repositories from assuming your cloud roles |
| `environment` | GitHub deployment environment name | Distinguishes between untrusted PR runs and human-approved production deployments |

---

## Claims Recording Sheet

Record observed non-secret claims here before deploying identity trust policies. **Never commit the raw JWT or signature.**

| Job Context | Environment | Target Cloud | Expected `aud` | Expected `sub` Format |
|---|---|---|---|---|
| PR Plan | `aws-plan` | AWS | `sts.amazonaws.com` | `repo:<org>/<repo>:environment:aws-plan` |
| Protected Apply | `aws-apply` | AWS | `sts.amazonaws.com` | `repo:<org>/<repo>:environment:aws-apply` |
| PR Plan | `azure-plan` | Azure | `api://AzureADTokenExchange` | `repo:<org>/<repo>:environment:azure-plan` |
| Protected Apply | `azure-apply` | Azure | `api://AzureADTokenExchange` | `repo:<org>/<repo>:environment:azure-apply` |

> **Note on GitHub Subject Formats:**  
> When a GitHub job runs without an environment, GitHub formats `sub` as:  
> - For branch pushes: `repo:<org>/<repo>:ref:refs/heads/<branch>`  
> - For pull requests: `repo:<org>/<repo>:pull_request`  
> When a job runs *with* an environment, GitHub always formats `sub` as:  
> - `repo:<org>/<repo>:environment:<env-name>`  
> Always use the environment-scoped subject to ensure approvals cannot be bypassed by pushing to a branch.
