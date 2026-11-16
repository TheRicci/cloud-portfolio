# Security model

## Enforced controls

| Control | Azure implementation | AWS implementation |
|---|---|---|
| Central inspection | Spoke UDRs send remote-spoke traffic to the NVA | Transit Gateway sends remote-spoke traffic to the inspection VPC and NVA |
| Least privilege | NVA permits only Spoke 1 → Spoke 2 TCP/8443 | Same stateful NVA policy |
| Safe return traffic | `conntrack` permits only `ESTABLISHED,RELATED` traffic | Same `conntrack` policy |
| Workload protection | No public IPs; NSGs protect workload subnets | No public IPs; Security Groups protect workload subnets |
| NVA management | Spokes cannot reach TCP/22 on the NVA | Spokes cannot reach the NVA management port |
| Evidence | NVA packet counters and validation output | NVA packet counters, TGW/VPC routes, and validation output |

## Validation principle

The test suite proves one allowed path and several denied paths. A denied test is an expected security control, not an intentionally introduced configuration flaw. Evidence is saved before resources are destroyed.

## Known limitations

- Each cloud implementation uses one NVA and one availability zone to keep a short-lived learning session inexpensive. It is not highly available.
- The NVA has layer-3/4 filtering only. It does not decrypt TLS, inspect HTTP content, or provide managed threat intelligence.
- General workload egress is outside this project's acceptance criteria. A production version needs explicit, centrally controlled egress and service-specific management connectivity.
- NVA kernel logs are local in this version. Production should export them to Log Analytics or CloudWatch Logs and alert on unexpected denies.

## Production hardening path

Replace the single NVA with redundant inspection appliances or managed firewall services, use multiple availability zones, export firewall logs centrally, and use dynamic routing where the number of spokes makes static route maintenance risky.
