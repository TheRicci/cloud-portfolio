# Hub-and-Spoke Network

> **Cloud:** Azure (Session 1) · AWS (Session 2)   
> **Unique angle:** Centrally inspected spoke traffic — default deny, with a validation matrix

---

## What problem does this solve?

A company grows and now has three teams — security, development and data — each with their own cloud network. Letting every network peer directly to every other creates an unmanageable web and no central enforcement point. How do you let teams communicate while controlling what gets through?

**Hub-and-spoke** puts one central network — the hub — in the middle. Every team network — a spoke — connects to the hub only. Any traffic between teams must pass through the hub first, where a firewall or appliance can inspect it, log it, and enforce policy.

The hub also hosts things everyone shares: a VPN connection back to the office, a DNS server, monitoring infrastructure. Teams get what they need without managing their own copies of shared services.

This is the same logic as a city's public transport hub: everything routes through a central station instead of needing a direct line from every suburb to every other suburb.

---

## When to use it

| Situation | Why hub-and-spoke fits |
|---|---|
| Multiple teams or business units on the same cloud | Each team gets their own spoke, isolated from others |
| Centralized security inspection required | All traffic passes through the hub where the firewall sits |
| Compliance requires traffic logging | One place to capture everything flowing between teams |
| Shared connection to office (VPN/ExpressRoute) | Put it in the hub once — all spokes get access |
| Teams are growing and you need a scalable pattern | Onboarding a new team = add a spoke, plug it in |

## When to avoid it

| Situation | Why hub-and-spoke hurts |
|---|---|
| Only 2–3 networks, no shared services | Hub adds cost and complexity with no benefit — direct peering is simpler |
| Spokes need high-throughput direct communication | Every packet takes an extra hop — latency and potential bottleneck |
| Hub has no redundancy | A single NVA or Firewall is a SPOF for all spoke communication |
| Simple single-team environment | A flat VNet or VPC is cheaper and easier |

---

## The key AWS vs Azure difference

**Azure:** VNet peering is non-transitive by default. A spoke cannot reach another spoke through the hub on its own. Azure lets you override this with user-defined routes (UDRs) pointing to an appliance in the hub that forwards traffic. Gateway transit lets spokes use the hub's VPN or ExpressRoute connection.

**AWS:** VPC peering is strictly non-transitive — there is no workaround with peering alone. The correct routing primitive is **Transit Gateway**, a managed regional router that connects VPCs explicitly and supports transitive routing. Transit Gateway routes traffic; this project adds an inspection VPC and NVA so the traffic is also filtered.


---

## Architecture

### Azure (Session 1)

```
┌──────────────────────────────────────────────┐
│  Hub VNet  10.0.0.0/16                       │
│                                              │
│  ┌─────────────────────────────────────┐     │
│  │  hub-subnet  10.0.1.0/24           │     │
│  │                                     │     │
│  │  NVA VM  10.0.1.4                  │     │
│  │  Ubuntu B1s · stateful iptables    │     │
│  └─────────────────────────────────────┘     │
└──────────────┬───────────────────────────────┘
               │  VNet Peering
               │  allow_forwarded_traffic = true
       ┌───────┴───────┐
       │               │
┌──────▼──────┐ ┌──────▼──────┐
│  Spoke 1    │ │  Spoke 2    │
│  10.1.0/16  │ │  10.2.0/16  │
│  10.1.1.4   │ │  10.2.1.4   │
└─────────────┘ └─────────────┘

UDR on each spoke: remote spoke CIDR → 10.0.1.4 (NVA)
```

### AWS (Session 2)

```
┌─────────────┐       ┌──────────────────────┐       ┌──────────────────┐
│  Spoke 1    │──────▶│   Transit Gateway    │──────▶│ Inspection VPC   │
│  10.11/16   │       │   (transitive router)│       │ + stateful NVA   │
└─────────────┘       └──────────────────────┘       └────────┬─────────┘
                                                               │
┌─────────────┐       ┌──────────────────────┐                │
│  Spoke 2    │◀──────│   Transit Gateway    │◀───────────────┘
│  10.12/16   │       │ inspection routes    │
└─────────────┘       └──────────────────────┘
```

---

## NVA policy — secure baseline

The NVA begins with a secure, stateful policy. The goal is to show the intended protection and its limits, not to create vulnerabilities on purpose.

| Rule | Intent |
|---|---|
| Spoke 1 → Spoke 2 TCP/8443 | Allow the one test service required by the project |
| `ESTABLISHED,RELATED` traffic | Allow replies without allowing Spoke 2 to initiate a new connection |
| All other inter-spoke traffic | Deny and write a bounded firewall log entry |
| Spoke → NVA TCP/22 | Deny management access from workload spokes |

Each workload VM runs a small Python HTTP server on TCP/8443. It is only a test fixture: it gives the network policy a real service to allow or deny. See [`docs/security-model.md`](docs/security-model.md) for controls, limitations, and production hardening.

---

## How to run

### Prerequisites

```bash
# Azure — set once per account
az login
az account set --subscription <your-subscription-id>

# Create your own remote-state storage once. The account name must be globally unique.
STATE_RG=rg-tfstate-portfolio
STATE_ACCOUNT=<globally-unique-storage-account-name>
az group create -n "$STATE_RG" -l brazilsouth
az storage account create -n "$STATE_ACCOUNT" -g "$STATE_RG" -l brazilsouth --sku Standard_LRS
az storage container create -n tfstate --account-name "$STATE_ACCOUNT" --auth-mode login

# Update cidr-plan.yaml home.lan with your actual home LAN range
```

### Session 1 — Azure

```bash
cd 01-hub-and-spoke/azure
export TF_VAR_admin_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
terraform init \
  -backend-config="resource_group_name=$STATE_RG" \
  -backend-config="storage_account_name=$STATE_ACCOUNT" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=01-hub-and-spoke/azure.tfstate"
terraform apply

# Save evidence
RG=$(terraform output -raw resource_group_name)
SPOKE1=$(terraform output -raw spoke1_vm_name)
SPOKE2=$(terraform output -raw spoke2_vm_name)
NVA=$(terraform output -raw nva_vm_name)

az network route-table list -g $RG -o table > ../evidence/route-tables.txt
az network nsg list -g $RG -o table        > ../evidence/nsg-rules.txt
az network vnet peering list --vnet-name vnet-hub-portfolio-hs -g $RG -o table \
                                           > ../evidence/peering-state.txt

# Run the validation matrix
cd ../tests
chmod +x connectivity.sh
./connectivity.sh $RG $SPOKE1 $SPOKE2 $NVA

# Destroy
cd ../azure
terraform destroy -auto-approve

# Commit evidence
cd ../..
git add evidence/
git commit -m "01-hub-and-spoke: Azure session 1 evidence"
```

### Session 2 — AWS

```bash
cd 01-hub-and-spoke/aws
# Create this versioned bucket once, then set the values for your account.
export TF_STATE_BUCKET=<your-state-bucket>
export TF_STATE_REGION=us-east-1
terraform init \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="region=$TF_STATE_REGION" \
  -backend-config="use_lockfile=true" \
  -backend-config="encrypt=true" \
  -backend-config="key=01-hub-and-spoke/aws.tfstate"
terraform apply

SPOKE1_ID=$(terraform output -raw spoke1_instance_id)
SPOKE2_ID=$(terraform output -raw spoke2_instance_id)
NVA_ID=$(terraform output -raw nva_instance_id)
SPOKE1_IP=$(terraform output -raw spoke1_private_ip)
SPOKE2_IP=$(terraform output -raw spoke2_private_ip)
NVA_IP=$(terraform output -raw nva_private_ip)

# Wait until all three instances appear as managed nodes in Systems Manager.
# The test uses the private SSM interface endpoints created by Terraform.
cd ../tests
chmod +x aws-connectivity.sh
./aws-connectivity.sh $SPOKE1_ID $SPOKE2_ID $NVA_ID $SPOKE1_IP $SPOKE2_IP $NVA_IP

# Save evidence
aws ec2 describe-transit-gateway-route-tables \
  --query 'TransitGatewayRouteTables[*].{ID:TransitGatewayRouteTableId,State:State}' \
  --output table > ../evidence/tgw-route-tables.txt

cd ../aws
terraform destroy -auto-approve
```

---



| File | Contents |
|---|---|
| [azure-connectivity-matrix.txt](evidence/azure-connectivity-matrix.txt) | Azure allowed/denied flow results |
| [aws-connectivity-matrix.txt](evidence/aws-connectivity-matrix.txt) | AWS allowed/denied flow results |
| [route-tables.txt](evidence/route-tables.txt) | Azure route table state |
| [nsg-rules.txt](evidence/nsg-rules.txt) | Azure NSG rules |
| [peering-state.txt](evidence/peering-state.txt) | VNet peering status |
| [tgw-route-tables.txt](evidence/tgw-route-tables.txt) | AWS TGW route table state |

---

## What this protects — and what it does not

| Protected now | Still a limitation |
|---|---|
| New, unapproved inter-spoke connections | Single NVA and single availability zone |
| Direct workload access to NVA management port | No TLS inspection or managed threat intelligence |
| Return traffic becoming a broad reverse-access rule | NVA logs remain local during this short-lived exercise |
| Public management access to test workloads | General workload egress is outside this project's scope |

The full explanation is in [`docs/security-model.md`](docs/security-model.md).

---


## Cost breakdown

| Resource | Cost approach |
|---|---|
| Azure VMs and AWS EC2 | Run only for the validation session |
| Azure VNet peering and AWS Transit Gateway | Keep traffic tiny; destroy promptly |
| AWS Systems Manager interface endpoints | Required for private management; destroy after testing |
| Remote Terraform state | Keep storage small and secure it separately |

Exact cost depends on the selected region and current pricing. Run a provider calculator before applying, then record the actual session cost with the saved evidence.

---

## Future possible modifications 

| This project | Production version | Why |
|---|---|---|
| Single Linux NVA | Redundant appliances or managed firewall across availability zones | Eliminates the central single point of failure |
| Local NVA firewall logs | Log Analytics or CloudWatch Logs with alerts | Creates an operational and forensic trail |
| Layer-3/4 policy only | Managed inspection with threat intelligence and, where justified, TLS inspection | Adds detection and application-aware controls |
| Static UDRs / TGW routes | Dynamic routing where the spoke count justifies it | Reduces manual route maintenance |
| 2 spokes | Per-team subscriptions with Management Groups + Azure Policy | Full enterprise landing zone pattern |
