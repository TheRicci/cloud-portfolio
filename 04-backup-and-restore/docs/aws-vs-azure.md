# AWS vs Azure — Backup & Restore Comparison

> This document is populated with measured data after running sessions on both clouds.
> Do not fill in estimates — only real numbers from `tests/results/`.

---

## Drill A — VM Restore

| Metric | AWS | Azure |
|--------|-----|-------|
| Backup size | — | — |
| Restore time (script clock) | — | — |
| Restore time (cloud job clock) | — | — |
| RTO (destroy → verify pass) | — | — |
| Data loss (rows) | — | — |
| Postgres WAL replay needed? | — | — |
| Postgres started cleanly? | — | — |

---

## Drill B — Logical Dump Restore

| Metric | AWS | Azure |
|--------|-----|-------|
| Dump size | — | — |
| Rows at time of dump | — | — |
| Rows at time of mistake | — | — |
| Rows lost (RPO gap) | — | — |
| Restore time | — | — |
| Checksum verification | — | — |

---

## Drill C — Object Recovery

| Metric | AWS | Azure |
|--------|-----|-------|
| Files overwritten | — | — |
| Files deleted | — | — |
| Recovery method | S3 versioning | Blob soft-delete + versioning |
| Recovery time (total) | — | — |
| All hashes matched? | — | — |

---

## Drill D — Deletion Protection

| Metric | AWS | Azure |
|--------|-----|-------|
| Mechanism | IAM deny policy | RBAC not_actions |
| Positive control (reboot/restart) | — | — |
| Delete recovery point | — | — |
| Delete vault | — | — |
| Exact error code | — | — |

---

## Check E — Restore Testing

| Metric | AWS | Azure |
|--------|-----|-------|
| Method | Scripted restore test | Scripted restore test |
| Restore time | — | — |
| Data verified? | — | — |
| Test VM deleted? | — | — |

---

## Cost Comparison

| Item | AWS | Azure |
|------|-----|-------|
| Estimated session cost | ~\$0.08 | ~\$0.24 |
| Actual session cost | — | — |
| Biggest cost item | Public IPv4 | Backup instance fee |

---

## Surprises and Differences

> Record anything unexpected here after running both sessions.
>
> Examples:
> - Which cloud's backup job was faster?
> - Did one cloud's restore require more manual steps?
> - Any commands that didn't work as documented?
> - Soft-delete teardown complications on Azure?
