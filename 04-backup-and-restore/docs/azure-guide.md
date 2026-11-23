# Azure Backup & Restore Guide

Complete step-by-step guide to deploying, running automated drills, tearing down, and verifying costs on **Azure**.

All commands run from `04-backup-and-restore/`. Environment variables and resource IDs are detected automatically from Terraform outputs.

---

## 1. One-Time Budget Alert Guardrail

Create a $5 budget alert before applying infrastructure:

```bash
az consumption budget create \
  --budget-name backup-lab-azure-guard \
  --amount 5 \
  --category Cost \
  --time-grain Monthly \
  --start-date "$(date -u +%Y-%m-01)" \
  --end-date "2027-12-31" \
  --notifications '{
    "alert80": {
      "enabled": true,
      "operator": "GreaterThanOrEqualTo",
      "threshold": 80,
      "contactEmails": ["YOUR_EMAIL@domain.com"]
    }
  }'
```

---

## 2. Deploy Infrastructure

```bash
cd azure

# Configure remote backend (optional or local for testing)
cp backend.tf.example backend.tf
# Edit backend.tf with your state storage account

# Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars:
#   location             = "eastus"
#   admin_ssh_public_key = "ssh-ed25519 AAAA..."  (your SSH public key)
#   alert_email          = "YOUR_EMAIL@domain.com"

terraform init
terraform plan
terraform apply
```

> **Note:** Wait 3–5 minutes after `terraform apply` finishes for cloud-init on the Azure Linux VM to format the managed data disk, configure PostgreSQL, compile the Go writer, and begin inserting rows.

---

## 3. Run Automated Session & Drills

You do **not** need to manually export any variables. The script extracts them directly from Terraform outputs:

```bash
cd ..
bash tests/run-azure.sh
```

---

## Detailed Step-by-Step Breakdown: What the Scripts Do

### Initialization & Output Auto-Detection (`tests/azure/run.sh`)
- Inspects `azure/` directory for Terraform state (`terraform.tfstate` or `.terraform`).
- Queries `terraform output -raw` to automatically retrieve:
  - `resource_group_name` (e.g. `rg-backup-lab`)
  - `vm_name` (e.g. `vm-backup-lab`)
  - `vm_id` (Azure Resource ID of the VM)
  - `storage_account_name` (Storage account for blobs and pg_dump)
  - `vault_name` (Azure Recovery Services vault)
  - `location` (e.g. `eastus`)
  - `subscription_id`
- Validates local tools (`jq`, `openssl`, `sha256sum`, `az`).
- Creates timestamped results folder: `tests/results/<timestamp>-azure/`.
- Sets a bash `trap` to run `teardown.sh` on exit (even on cancellation or failure).

---

### Step 1: Preflight Verification (`tests/azure/drills/preflight.sh`)
- **Subscription Matching**: Calls `az account show` to confirm the active subscription matches Terraform's target.
- **Budget Guardrail Check**: Queries `az consumption budget list` to ensure the $5 monthly cost alert is registered.
- **Leftover Check**: Queries `az resource list --tag project=backup-lab` to check currently deployed assets.

---

### Step 2: Baseline Backup (`tests/azure/drills/backup.sh`)
- **Writer Health & Rising Data**:
  - Connects to the VM via **Azure VM Run Command** (`az vm run-command invoke --command-id RunShellScript`).
  - Verifies PostgreSQL is active and queries `SELECT count(*) FROM events;`.
  - Samples row counts twice with a 5-second interval to confirm the Go writer is inserting rows into the database.
- **Blob Storage Seeding**:
  - Generates 20 small files with unique random strings.
  - Uploads them to the Azure Blob Storage container `files` using Azure CLI with `--auth-mode login`.
  - Creates a local manifest (`file-manifest.json`) storing file names and SHA-256 hashes.
- **VM Disk Snapshot via Recovery Services**:
  - Triggers an on-demand snapshot via `az backup protection backup-now` targeting the VM container.
  - Polls `az backup job show` until the status transitions to `Completed`.
- **Database Logical Dump**:
  - Executes `pg_dump backuplab` inside the VM via Run Command.
  - Directly uploads the dump to Azure Blob container `dumps` using the VM's assigned Managed Identity.

---

### Step 3: Drill A — VM Loss & Disk Restore (`tests/azure/drills/drill-a.sh`)
- **Pre-Disaster State**: Queries and records the highest committed row ID and timestamp.
- **Disaster Simulation**: Deletes the Linux VM (`az vm delete --yes`) and the attached managed data disk (`az disk delete --yes`).
- **Recovery via Recovery Services Vault**:
  - Locates the latest recovery point using `az backup recoverypoint list`.
  - Initiates `az backup restore restore-disks` to restore the OS and data disks to the staging storage account.
  - Polls the backup restore job until `Completed`.
  - Locates the restored managed disk and recreates the VM with `az vm create --attach-os-disk`, assigning it a new NIC and tagging it with `project=backup-lab` and `session_id=<RUN_ID>`.
- **Post-Restore Verification**:
  - Verifies PostgreSQL starts up on the recreated VM.
  - Inspects journal logs for WAL redo entries.
  - Runs checksum validation (`sha256(payload) == checksum`) across all restored rows.
  - Records:
    - **RTO**: Total time from VM deletion command to completed checksum pass.
    - **RPO**: Difference between the pre-disaster last row and restored rows.

---

### Step 4: Drill B — Bad Data & Logical Dump Restore (`tests/azure/drills/drill-b.sh`)
- **Mistake Simulation**:
  - Executes `DELETE FROM events WHERE id > <threshold>;` to wipe out recent table data.
  - Confirms row loss.
- **Logical Restore**:
  - Downloads the `dump-<RUN_ID>.sql` file from Blob Storage container `dumps`.
  - Loads the dump into a clean database `backuplab_restored`.
- **Verification & RPO Gap**:
  - Verifies 100% checksum integrity in the restored database.
  - Reports rows lost between the dump snapshot and the delete query.
  - Restores the original table from the dump and cleans up temporary databases.

---

### Step 5: Drill C — Blob Corruption & Version/Soft-Delete Recovery (`tests/azure/drills/drill-c.sh`)
- **Blob Damage Simulation**:
  - Overwrites the first 5 blobs with `CORRUPTED CONTENT` using `--overwrite`.
  - Deletes the next 5 blobs using `az storage blob delete`.
- **Dual Recovery**:
  - **Overwritten Blobs (Versioning)**: Queries `az storage blob list --include v` for previous version IDs, and copies the historical version back over the current blob using `az storage blob copy start`.
  - **Deleted Blobs (Soft Delete)**: Invokes `az storage blob undelete` to restore soft-deleted blobs back to active state.
- **Verification**:
  - Downloads all 20 files and verifies their SHA-256 hashes against `file-manifest.json`.

---

### Step 6: Drill D — RBAC Deletion Protection (`tests/azure/drills/drill-d.sh`)
- **Identity Evaluation**:
  - Inspects the user-assigned managed identity `backup-lab-limited` and its custom RBAC role definition `backup-lab-limited-role`.
- **Positive Control (Must Succeed)**:
  - Verifies that VM restart action (`Microsoft.Compute/virtualMachines/restart/action`) is granted and executable.
- **Negative Controls (Must Be Denied)**:
  - Confirms that `not_actions` in the custom role explicitly block:
    - `Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems/delete`
    - `Microsoft.RecoveryServices/vaults/delete`
  - Logs verified permissions in `tests/results/<timestamp>-azure/drill-d-errors.txt`.

---

### Step 7: Check E — Native/Scripted Restore Verification (`tests/azure/drills/check-e.sh`)
- Queries the Recovery Services vault to verify that the generated recovery points are accessible and in healthy state.
- Validates end-to-end restorability using data gathered from Drill A.

---

### Step 8: Teardown & Soft-Delete Purge (`tests/azure/teardown.sh` & `audit.sh`)
Executed automatically on exit, or manually via `bash tests/teardown-azure.sh`:
1. **Deletes Restored Resources**: Removes restored VMs, unattached managed disks, and orphaned NICs.
2. **Azure Soft-Delete Purge Sequence**:
   - Azure enforces "Secure by Default" soft-delete on Recovery Services vaults (vault deletion fails if soft-deleted items exist).
   - The script queries all soft-deleted items and executes `az backup protection undelete`.
   - Then runs `az backup protection disable --delete-backup-data true --yes` to permanently wipe the data.
3. **Terraform Destroy**: Runs `terraform destroy -auto-approve` in `azure/` to tear down resource group, storage account, and networking.
4. **Leftover Audit**: Runs `tests/azure/audit.sh` querying VMs, disks, vaults, storage accounts, public IPs, and NICs. Exits with code `0` if clean.

---

## 5. Next-Day Cost Verification

Billing data lags by 24 hours. The next day, check Azure Cost Management:

In the Azure Portal, navigate to:
**Cost Management + Billing → Cost Analysis → Filter by Resource group: `rg-backup-lab`**.

Expected session cost: **~$0.22 – $0.30** (includes prorated daily protected instance fee of ~$0.17). Write this number into `README.md` and `docs/aws-vs-azure.md`.
