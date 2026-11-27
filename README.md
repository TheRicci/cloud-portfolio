# cloud-portfolio

Infrastructure projects across AWS and Azure — built to demonstrate production patterns.

---

## Projects

| # | Project | Status | Cloud | Unique angle |
|---|---|---|---|---|
| 01 | [Hub-and-Spoke Network](./01-hub-and-spoke/) | 🔨 Building | Azure + AWS | Centrally inspected, default-deny spoke traffic |
| 02 | [IAM & OIDC Federation](./02-iam-oidc/) | 🔨 Building | AWS + Azure | Zero long-lived credentials, Checkov enterprise scanning, 6-phase walkthrough & showcase VM |
| 03 | [Observability and Alerting](./03-observability/) | 🔨 Building | AWS + Azure + Docker | Full-stack RED/USE metrics, Loki logs, multi-cloud alerting, Grafana & Prometheus |
| 04 | [Backup and Restore Lab](./04-backup-and-restore/) | 🔨 Building | AWS + Azure | Multi-cloud backup and recovery drills with measured RTO/RPO |
| 05 | [Hardening and Drift](./05-hardening-drift/) | 🔨 Building | AWS + Azure | Pull-mode Ansible OS hardening, Lynis before/after scoring, external probes & timed self-repair |

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
│   ├── README.md
│   ├── azure/              # Terraform root — own state
│   ├── aws/                # Terraform root — own state
│   ├── tests/              # Test scripts
│   ├── evidence/           # Committed validation output from real sessions
│   └── docs/               # Security model, design decisions, comparisons
├── 02-iam-oidc/
│   ├── README.md
│   ├── .checkov.yaml       # Checkov enterprise IaC scanner configuration
│   ├── demo-walkthrough.sh # 6-phase interactive walkthrough & automation harness
│   ├── bootstrap/          # One-time local state-backend setup (S3 / Blob)
│   ├── aws/                # AWS OIDC provider, plan/apply roles, boundary
│   ├── azure/              # Entra apps, federated credentials, scoped RBAC
│   ├── workload/           # Self-contained showcase VM workload (AWS + Azure)
│   ├── tests/              # Security invariant tests & recorded proof logs
│   └── docs/               # In-depth walkthrough guide, activation & comparisons
├── 03-observability/
│   ├── service/            # Go workload and separate loopback-only admin listener
│   ├── compose/            # Prometheus, Alertmanager, Alloy, and k6
│   ├── aws/                # Isolated AWS Terraform root
│   ├── azure/              # Isolated Azure Terraform root
│   ├── grafana/            # Dashboard and alert exports
│   ├── tests/              # Static gate and per-cloud session scripts
│   └── docs/               # Operational comparison notes
├── 04-backup-and-restore/
│   ├── README.md
│   ├── aws/                # AWS Backup + S3 backup infrastructure
│   ├── azure/              # Recovery Services Vault + Blob backup
│   ├── workload/           # Target VM + Postgres + Go generator
│   ├── docs/               # AWS and Azure deployment & drill guides
│   └── tests/              # Automated backup and restore drills (RTO/RPO)
└── 05-hardening-drift/
    ├── README.md
    ├── ansible/            # local.yml, hardening role, pull wrapper & systemd timer
    ├── common/             # Shared cloud-init bootstrap (weak baseline, decoy, bundle)
    ├── aws/                # Isolated AWS Terraform root
    ├── azure/              # Isolated Azure Terraform root
    ├── tests/              # Session runner, outside probes, on-VM checks & results
    ├── ci/                 # Static-check workflow template
    └── docs/               # AWS vs Azure measured results comparison
```

---

## Standards (applied to every project)

- **Terraform only** — no console clicks, no manual state
- **Evidence committed** — plain-text validation output saved before `terraform destroy`
- **Destroy after every session** — hourly-billed resources never left running

---
