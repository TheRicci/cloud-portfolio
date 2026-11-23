# AWS Backup & Restore Guide

Complete step-by-step guide to deploying, running automated drills, tearing down, and verifying costs on **AWS**.

All commands run from `04-backup-and-restore/`. Environment variables and resource IDs are detected automatically from Terraform outputs.

---

## 1. One-Time Budget Alert Guardrail

Create a $5 budget alert before applying infrastructure:

```bash
aws budgets create-budget \
  --account-id "$(aws sts get-caller-identity --query Account --output text)" \
  --budget '{
    "BudgetName": "backup-lab-aws-guard",
    "BudgetLimit": {"Amount": "5", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }' \
  --notifications-with-subscribers '[{
    "Notification": {
      "NotificationType": "ACTUAL",
      "ComparisonOperator": "GREATER_THAN",
      "Threshold": 80,
      "ThresholdType": "PERCENTAGE"
    },
    "Subscribers": [{"SubscriptionType": "EMAIL", "Address": "YOUR_EMAIL@domain.com"}]
  }]'
```

---

## 2. Deploy Infrastructure

```bash
cd aws

# Configure remote backend (optional or local for testing)
cp backend.tf.example backend.tf
# Edit backend.tf with your S3 state bucket

# Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars:
#   region      = "us-east-1"
#   alert_email = "YOUR_EMAIL@domain.com"

terraform init
terraform plan
terraform apply
```

> **Note:** Wait 3–5 minutes after `terraform apply` finishes for cloud-init on the EC2 instance to format the data volume, start PostgreSQL, build the Go writer, and begin inserting rows.

---

## 3. Run Automated Session & Drills

You do **not** need to manually export any variables. The script extracts them directly from Terraform outputs:

```bash
cd ..
bash tests/run-aws.sh
```

---

## Detailed Step-by-Step Breakdown: What the Scripts Do

### Initialization & Output Auto-Detection (`tests/aws/run.sh`)
- Inspects `aws/` directory for Terraform state (`terraform.tfstate` or `.terraform`).
- Queries `terraform output -raw` to automatically retrieve:
  - `instance_id` (EC2 instance to back up and destroy)
  - `region` (e.g. `us-east-1`)
  - `bucket_name` (S3 bucket with versioning enabled)
  - `backup_vault_name` (AWS Backup vault)
  - `backup_service_role_arn` (IAM role used by AWS Backup to snapshot and restore EC2/EBS)
  - `limited_role_arn` (Restricted IAM role used for deletion protection testing)
- Validates local tools (`jq`, `openssl`, `sha256sum`, `aws`).
- Creates a timestamped session results folder: `tests/results/<timestamp>-aws/`.
- Registers a bash `trap` to run `teardown.sh` on exit (even if canceled via Ctrl+C).

---

### Step 1: Preflight Verification (`tests/aws/drills/preflight.sh`)
- **Account Identity**: Calls `aws sts get-caller-identity` to verify connected account and region.
- **Budget Guardrail Check**: Queries `aws budgets describe-budgets` to ensure the $5 safety alert exists.
- **Leftover Check**: Queries AWS Resource Groups Tagging API for any leftover resources tagged `project=backup-lab` from previous sessions.

---

### Step 2: Baseline Backup (`tests/aws/drills/backup.sh`)
- **Writer Health & Rising Data**:
  - Connects to the VM via **AWS Systems Manager (SSM) Run Command** (no SSH keys or inbound ports required).
  - Verifies PostgreSQL service is active and queries `SELECT count(*) FROM events;`.
  - Takes two count measurements 5 seconds apart to confirm the Go writer is actively inserting ~1 row/sec.
- **Object Storage Seeding**:
  - Generates 20 small test files with random payloads.
  - Uploads them to `s3://$BUCKET_NAME/files/testfile-001.txt` ... `020.txt`.
  - Creates a local manifest (`file-manifest.json`) containing file names and SHA-256 hashes.
- **EC2 & EBS Snapshot Backup**:
  - Triggers an on-demand AWS Backup job using `aws backup start-backup-job` targeting the EC2 instance ARN.
  - Polls `aws backup describe-backup-job` until status transitions to `COMPLETED`.
- **Database Logical Dump**:
  - Runs `pg_dump backuplab` inside the VM via SSM.
  - Uploads the dump directly to `s3://$BUCKET_NAME/dumps/dump-<RUN_ID>.sql`.

---

### Step 3: Drill A — VM Loss & Snapshot Restore (`tests/aws/drills/drill-a.sh`)
- **Pre-Disaster Timestamp**: Queries the VM via SSM for the latest committed row (`id` and `written_at`), saved locally on the laptop.
- **Disaster Simulation**: Terminates the EC2 instance using `aws ec2 terminate-instances` and waits until `instance-terminated`.
- **Recovery via AWS Backup**:
  - Retrieves the latest recovery point ARN from `backup-lab-vault`.
  - Initiates `aws backup start-restore-job` with subnet, security group, and instance profile parameters.
  - Polls `describe-restore-job` until complete.
  - Extracts the newly provisioned instance ID from `CreatedResourceArn`.
  - Immediately tags the restored instance with `project=backup-lab` and `session_id=<RUN_ID>`.
- **Post-Restore Verification**:
  - Waits for the restored VM to register as `Online` in SSM.
  - Checks if PostgreSQL started automatically (`systemctl is-active postgresql`).
  - Inspects PostgreSQL journal logs for WAL replay (`redo`, `recovery`, `replay`) to observe crash-consistent snapshot recovery.
  - Queries `SELECT count(*) FROM events WHERE checksum != encode(sha256(payload::bytea), 'hex');` to confirm zero data corruption.
  - Computes and records:
    - **RTO (Recovery Time Objective)**: Clock time from instance termination to successful checksum verification.
    - **RPO (Recovery Point Objective)**: Number of rows missing between the last recorded row and the restored dataset.

---

### Step 4: Drill B — Bad Data & Logical Dump Restore (`tests/aws/drills/drill-b.sh`)
- **Mistake Simulation**:
  - Runs a destructive `DELETE FROM events WHERE id > <midpoint>;` query via SSM to simulate an accidental or malicious wipe of recent data.
  - Verifies row count dropped.
- **Logical Recovery**:
  - Downloads `dump-<RUN_ID>.sql` from S3 onto the restored VM.
  - Creates a temporary database `backuplab_restored` and loads the dump.
- **Verification & RPO Gap**:
  - Confirms checksums in `backuplab_restored` match 100%.
  - Calculates the exact rows lost between the dump timestamp and the mistake timestamp.
  - Documents the honest limitation of dump-only backups (requires continuous managed PITR to close).
  - Restores the production `backuplab` table from the dump and cleans up the temporary database.

---

### Step 5: Drill C — S3 Object Corruption & Version Recovery (`tests/aws/drills/drill-c.sh`)
- **File Damage Simulation**:
  - Overwrites the first 5 seeded files in S3 with `CORRUPTED CONTENT`.
  - Deletes the next 5 seeded files using `aws s3 rm` (which creates S3 delete markers).
- **Version Recovery**:
  - For overwritten files: queries `aws s3api list-object-versions`, extracts the previous version ID (`Versions[1].VersionId`), and copies it over the current version.
  - For deleted files: queries `DeleteMarkers[0].VersionId` and permanently removes the delete marker, restoring the object to view.
- **Verification**:
  - Downloads all 20 files from S3 and re-computes their SHA-256 hashes against `file-manifest.json`.
  - Records total recovery duration.

---

### Step 6: Drill D — IAM Deletion Protection (`tests/aws/drills/drill-d.sh`)
- **Assumed Limited Role**:
  - Calls `aws sts assume-role` using the pre-provisioned `backup-lab-limited` IAM role.
- **Positive Control (Must Succeed)**:
  - Dispatches `aws ec2 reboot-instances` using the assumed temporary credentials. Confirms success (proving the role has operational rights).
- **Negative Controls (Must Be Denied)**:
  - Attempts `aws backup delete-recovery-point` using the limited credentials. Confirms denial (`AccessDeniedException`).
  - Attempts `aws backup delete-backup-vault` using the limited credentials. Confirms denial (`AccessDeniedException`).
  - Appends raw denial error logs to `tests/results/<timestamp>-aws/drill-d-errors.txt`.

---

### Step 7: Check E — Scripted Restore Testing (`tests/aws/drills/check-e.sh`)
- Validates restore viability without waiting for production failure:
  - Triggers an automated restore of the latest vault recovery point into a temporary test instance `backup-lab-test`.
  - Waits for completion, verifies instance connectivity and row counts.
  - Immediately terminates the test instance.

---

### Step 8: Teardown & Audit (`tests/aws/teardown.sh` & `audit.sh`)
Executed automatically on exit, or manually via `bash tests/teardown-aws.sh`:
1. **Terminates Restored Resources**: Finds any EC2 instances tagged `project=backup-lab` and terminates them.
2. **Empties Vault**: AWS Backup prohibits deleting vaults that hold recovery points. Lists and deletes all recovery points.
3. **Deletes Detached Volumes**: Scans for and removes unattached EBS volumes tagged `project=backup-lab`.
4. **Terraform Destroy**: Executes `terraform destroy -auto-approve` in `aws/` to remove VPC, S3 bucket, IAM roles, and base resources.
5. **Leftover Audit**: Runs `tests/aws/audit.sh` querying instances, volumes, snapshots, vaults, recovery points, S3 buckets, and Elastic IPs. Exits with code `0` if clean.

---

## 5. Next-Day Cost Verification

Billing data lags by 24 hours. The next day, check AWS Cost Explorer:

```bash
aws ce get-cost-and-usage \
  --time-period "Start=$(date -u -d yesterday +%Y-%m-%d),End=$(date -u +%Y-%m-%d)" \
  --granularity DAILY \
  --metrics BlendedCost \
  --filter '{"Tags": {"Key": "project", "Values": ["backup-lab"]}}' \
  --query 'ResultsByTime[0].Total.BlendedCost' \
  --output text
```

Expected session cost: **~$0.06 – $0.10**. Write this number into `README.md` and `docs/aws-vs-azure.md`.
