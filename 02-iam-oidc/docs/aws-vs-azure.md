# AWS vs. Azure: OIDC Federation Architectural Deep Dive

Both AWS and Azure provide native mechanisms to exchange short-lived GitHub Actions OIDC tokens for temporary cloud access. However, their security models, trust anchors, and authorization primitives differ significantly.

---

## Architecture Comparison

```
+-----------------------------------+-----------------------------------+
|               AWS                 |               Azure               |
+-----------------------------------+-----------------------------------+
| 1. IAM OpenID Connect Provider    | 1. Entra ID App Registration      |
|    (Global trust anchor)          |    (Identity container)           |
|                                   |                                   |
| 2. IAM Role Trust Policy          | 2. Federated Identity Credential  |
|    (Condition StringEquals on sub)|    (1 credential per subject)     |
|                                   |                                   |
| 3. Permission Boundary            | 3. Scoped Azure RBAC              |
|    (Ceiling on delegated roles)   |    (Contributor on Resource Group)|
|                                   |                                   |
| 4. sts:AssumeRoleWithWebIdentity  | 4. OAuth 2.0 Client Assertion     |
|    (Returns STS session token)    |    (Returns Entra access token)   |
+-----------------------------------+-----------------------------------+
```

---

## Detailed Comparison Matrix

| Concern | AWS | Azure |
|---|---|---|
| **Trust Configuration** | Created once per account as an `aws_iam_openid_connect_provider`. Trust conditions are defined inside each IAM Role's `assume_role_policy`. | Configured per Entra Application as an `azuread_application_federated_identity_credential`. |
| **Audience (`aud`)** | Fixed to `sts.amazonaws.com` by AWS STS. | Set to `api://AzureADTokenExchange` by Microsoft Entra ID. |
| **Subject Matching** | Flexible condition operators (`StringEquals`, `StringLike`). **Risk:** Engineers often mistakenly use `StringLike` with wildcards. | Exact literal string matching on `subject`. Entra ID does not support wildcards in federated credential subjects. |
| **Authorization Scope** | IAM Policies attached to the role. | Azure RBAC Role Assignments (`Reader` or `Contributor`) scoped to a specific Subscription or Resource Group. |
| **Blast Radius Mitigation** | **IAM Permission Boundary:** Maximum permissions ceiling that prevents the apply role from creating rogue admin roles. | **Resource Group Scope:** The identity is given Contributor on a single Resource Group and cannot touch other groups or assign roles. |
| **Remote State Isolation** | S3 Bucket Policy restricts `s3:ListBucket` by prefix and limits object read/write/delete strictly to the state key and `.tflock`. | RBAC assignment grants `Storage Blob Data Contributor` scoped directly to the individual `tfstate` container. |
| **Audit Evidence** | CloudTrail logs `AssumeRoleWithWebIdentity` calls, capturing token issuer, subject, and the generated session name (`gh-<run-id>`). | Entra ID Sign-in Logs (Workload Identities) and Azure Activity Log show federated authentication events. |

---

## Practical Takeaways: Which Model Fits Better?

1. **Simplicity and Auditability: Azure Wins**
   - Azure's Federated Identity Credential requires an exact match on `issuer`, `audience`, and `subject`. There is no way to accidentally write an overly permissive wildcard condition in Entra ID.
   - Scoping permissions to a Resource Group is intuitive and cleanly prevents lateral movement across other cloud assets.

2. **Fine-Grained Delegation: AWS Wins**
   - AWS allows an apply role to create other IAM roles dynamically (e.g. for serverless functions, ECS tasks), *provided* an IAM Permission Boundary is strictly enforced.
   - In Azure, granting permission to create role assignments almost always exposes the tenant to privilege escalation risks unless custom roles or privileged identity management (PIM) are introduced.
