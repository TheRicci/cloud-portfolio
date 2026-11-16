# cloud-portfolio

Infrastructure projects across AWS and Azure — built to demonstrate production patterns, not tutorials.

Each project has a written requirement, a validation matrix with allowed and denied paths, evidence from a real deployment, and a cost breakdown. Infrastructure is the focus; a minimal test workload is used when it makes a network assertion real.

---

## Projects

| # | Project | Status | Cloud | Unique angle |
|---|---|---|---|---|
| 01 | [Hub-and-Spoke Network](./01-hub-and-spoke/) | 🔨 Building | Azure + AWS | Centrally inspected, default-deny spoke traffic |
| 02 | [Observability and Alerting](./03-observability/) | 🔨 Building | Azure + AWS + Grafana Cloud | Multi-layer alerting and cross-cloud logs |




---

## Repo Structure

```
cloud-portfolio/
├── README.md
├── cidr-plan.yaml          # Full address plan — CI fails on overlaps
├── shared/
│   ├── ci/                 # Reusable GitHub Actions templates
│   └── scripts/            # CIDR overlap checker, shared helpers
├── 01-hub-and-spoke/
    ├── README.md
    ├── azure/              # Terraform root — own state
    ├── aws/                # Terraform root — own state
    ├── tests/              # Test scripts
    ├── evidence/           # Committed validation output from real sessions
    └── docs/               # Security model, design decisions, comparisons


```

---

## Standards (applied to every project)

- **Terraform only** — no console clicks, no manual state
- **Remote state** — Azure Storage or S3 with locking, never local
- **OIDC federation** — no long-lived cloud credentials committed
- **Evidence committed** — plain-text validation output saved before `terraform destroy`
- **Destroy after every session** — hourly-billed resources never left running
- **Budget alert first** — set before any `terraform apply`

---


