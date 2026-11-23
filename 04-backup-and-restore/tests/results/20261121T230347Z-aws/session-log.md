2026-11-21T23:03:47Z  === Starting AWS Backup Lab Session ===
2026-11-21T23:03:47Z  run_id=20261121T230347Z-aws
2026-11-21T23:03:47Z  --- Step 1: Preflight ---
2026-11-21T23:03:49Z  AWS account=5633****5515 region=us-east-1
2026-11-21T23:03:51Z  AWS budgets found: 1
2026-11-21T23:03:53Z  tagged resources found: 22
2026-11-21T23:03:53Z  PASS  preflight — AWS account and budget verification complete
2026-11-21T23:03:53Z  --- Step 2: Backup ---
2026-11-21T23:03:53Z  waiting for VM and writer...
2026-11-21T23:04:04Z  writer is running, row count=1671
2026-11-21T23:04:29Z  rows rising: 1681 -> 1696
2026-11-21T23:04:29Z  seeding 20 test files to S3...
2026-11-21T23:05:11Z  seeded 20 files, manifest at /c/Users/Ricci/Documents/GitHub/cloud-portfolio/04-backup-and-restore/tests/results/20261121T230347Z-aws/file-manifest.json
2026-11-21T23:05:11Z  triggering AWS Backup on-demand job...
2026-11-21T23:05:14Z  AWS Backup job started: 2768924f-8365-4af3-80eb-1eff2f6900ed
2026-11-21T23:06:17Z    backup job 2768924f-8365-4af3-80eb-1eff2f6900ed: RUNNING (60s)
2026-11-21T23:07:21Z    backup job 2768924f-8365-4af3-80eb-1eff2f6900ed: RUNNING (120s)
2026-11-21T23:08:24Z    backup job 2768924f-8365-4af3-80eb-1eff2f6900ed: RUNNING (180s)
2026-11-21T23:09:27Z    backup job 2768924f-8365-4af3-80eb-1eff2f6900ed: RUNNING (240s)
2026-11-21T23:10:30Z    backup job 2768924f-8365-4af3-80eb-1eff2f6900ed: RUNNING (300s)
2026-11-21T23:11:33Z    backup job 2768924f-8365-4af3-80eb-1eff2f6900ed: RUNNING (360s)
2026-11-21T23:12:36Z    backup job 2768924f-8365-4af3-80eb-1eff2f6900ed: RUNNING (420s)
2026-11-21T23:13:39Z    backup job 2768924f-8365-4af3-80eb-1eff2f6900ed: RUNNING (480s)
2026-11-21T23:14:42Z    backup job 2768924f-8365-4af3-80eb-1eff2f6900ed: RUNNING (540s)
2026-11-21T23:15:45Z    backup job 2768924f-8365-4af3-80eb-1eff2f6900ed: RUNNING (600s)
2026-11-21T23:16:48Z    backup job 2768924f-8365-4af3-80eb-1eff2f6900ed: RUNNING (660s)
2026-11-21T23:17:51Z    backup job 2768924f-8365-4af3-80eb-1eff2f6900ed: RUNNING (720s)
2026-11-21T23:18:54Z    backup job 2768924f-8365-4af3-80eb-1eff2f6900ed: RUNNING (780s)
2026-11-21T23:19:57Z    backup job 2768924f-8365-4af3-80eb-1eff2f6900ed: RUNNING (840s)
2026-11-21T23:21:01Z    backup job 2768924f-8365-4af3-80eb-1eff2f6900ed: RUNNING (900s)
2026-11-21T23:22:04Z    backup job 2768924f-8365-4af3-80eb-1eff2f6900ed: COMPLETED (960s)
2026-11-21T23:22:04Z  AWS Backup job completed
2026-11-21T23:22:04Z  running pg_dump on VM...
2026-11-21T23:22:15Z  pg_dump uploaded to s3://backup-lab-488ca9ca92ec006e11ff96711d/dumps/dump-20261121T230347Z-aws.sql
2026-11-21T23:22:15Z  PASS  backup — all AWS backups completed in 1102s
2026-11-21T23:22:15Z  --- Step 3: Drill A — VM Loss & Restore ---
2026-11-21T23:22:26Z  last row: id=2772 at=2026-11-2123:22:17.527233+00
2026-11-21T23:22:26Z  terminating EC2 VM...
2026-11-21T23:22:28Z  waiting for instance termination...
2026-11-21T23:23:00Z  EC2 VM terminated
2026-11-21T23:23:02Z  restoring from recovery point: arn:aws:ec2:us-east-1::image/ami-051b1adf907ba1fab
2026-11-21T23:23:11Z  restore job started: 28aadae5-e6c4-4272-84e3-3e3b2461941f
2026-11-21T23:24:15Z    restore job 28aadae5-e6c4-4272-84e3-3e3b2461941f: RUNNING (60s)
2026-11-21T23:25:18Z    restore job 28aadae5-e6c4-4272-84e3-3e3b2461941f: COMPLETED (120s)
2026-11-21T23:25:19Z  restored instance: i-04759c1cffa43293c
2026-11-21T23:25:22Z  waiting for restored VM to register with SSM...
2026-11-21T23:25:23Z  verifying restored Postgres & dataset...
2026-11-21T23:25:34Z  Postgres is running after restore
2026-11-21T23:25:44Z  restored row count: 1819 (pre-crash last row: 2772)
2026-11-21T23:25:54Z  checksum verification passed — 0 corrupted rows
2026-11-21T23:25:55Z  PASS  drill-a — restored and verified. RTO=219s, data_loss=953 rows
2026-11-21T23:25:55Z  --- Step 4: Drill B — Data Loss & Logical Dump Restore ---
2026-11-21T23:26:05Z  last row: id=1862 at=2026-11-2123:25:57.621601+00
2026-11-21T23:26:05Z  pre-mistake last row: id=1862
2026-11-21T23:26:05Z  running bad DELETE: id > 931
2026-11-21T23:26:26Z  rows after bad delete: 941 (was: 1862)
2026-11-21T23:26:26Z  restoring from logical dump: dump-20261121T230347Z-aws.sql
2026-11-22T00:09:16Z  rows in restored database: 2761
2026-11-22T00:09:47Z  restoring original backuplab database from dump...
2026-11-22T00:11:46Z  PASS  drill-b — checksums OK. rows_lost=0 (RPO gap). RTO=2751s
2026-11-22T00:11:46Z  --- Step 5: Drill C — S3 Object Corruption & Version Recovery ---
2026-11-22T00:11:47Z  overwriting S3 files: testfile-001.txt testfile-002.txt testfile-003.txt testfile-004.txt testfile-005.txt
2026-11-22T00:11:47Z  deleting S3 files: testfile-006.txt testfile-007.txt testfile-008.txt testfile-009.txt testfile-010.txt
2026-11-22T00:12:02Z  S3 test files corrupted and deleted
2026-11-22T00:12:02Z  recovering S3 files from versions...
2026-11-22T00:12:32Z  S3 recovery operations complete
2026-11-22T00:13:20Z  file verification passed — all 20 files match
2026-11-22T00:13:20Z  PASS  drill-c — all S3 files recovered and verified in 94s
2026-11-22T00:13:20Z  --- Step 6: Drill D — IAM Deletion Protection ---
2026-11-22T00:13:20Z  assuming limited IAM role: arn:aws:iam::5633****5515:role/backup-lab-limited
2026-11-22T00:13:23Z  positive control: rebooting EC2 instance with limited role...
2026-11-22T00:13:25Z  PASS: EC2 reboot succeeded (positive control)
2026-11-22T00:13:42Z  attempting to delete recovery point (must be DENIED)...
2026-11-22T00:13:43Z  DENIED: delete-recovery-point — 
aws: [ERROR]: An error occurred (AccessDeniedException) when calling the DeleteRecoveryPoint operation: User: arn:aws:sts::5633****5515:assumed-role/backup-lab-limited/drill-d-20261121T230347Z-aws is not authorized to perform: backup:DeleteRecoveryPoint on resource: arn:aws:ec2:us-east-1::image/ami-051b1adf907ba1fab with an explicit deny in an identity-based policy
2026-11-22T00:13:44Z  attempting to delete vault (must be DENIED)...
2026-11-22T00:13:45Z  DENIED: delete-backup-vault — 
aws: [ERROR]: An error occurred (AccessDeniedException) when calling the DeleteBackupVault operation: User: arn:aws:sts::5633****5515:assumed-role/backup-lab-limited/drill-d-20261121T230347Z-aws is not authorized to perform: backup:DeleteBackupVault on resource: arn:aws:backup:us-east-1:5633****5515:backup-vault:backup-lab-vault with an explicit deny in an identity-based policy
2026-11-22T00:13:45Z  PASS  drill-d — deletion protection verified in 25s (errors in drill-d-errors.txt)
2026-11-22T00:13:45Z  --- Step 7: Check E — Native/Scripted Restore Testing ---
2026-11-22T00:13:46Z  running scripted AWS restore test...
2026-11-22T00:13:47Z  restore test from: arn:aws:ec2:us-east-1::image/ami-051b1adf907ba1fab
2026-11-22T00:13:56Z  restore test job: 1362c955-82f4-4e26-8e27-dced289d4ff3
2026-11-22T00:14:59Z    restore job 1362c955-82f4-4e26-8e27-dced289d4ff3: RUNNING (60s)
2026-11-22T00:16:02Z    restore job 1362c955-82f4-4e26-8e27-dced289d4ff3: COMPLETED (120s)
2026-11-22T00:16:04Z  test instance: i-03d30f672e19f6a6a
2026-11-22T00:16:06Z  cleaning up test instance: i-03d30f672e19f6a6a...
2026-11-22T00:16:09Z  PASS  check-e — AWS restore test completed in 144s
2026-11-22T00:16:09Z  === All AWS Drills Passed Successfully ===
2026-11-22T00:16:09Z  === Auto-Teardown (exit trap) ===
2026-11-22T00:16:09Z  === Teardown: AWS ===
2026-11-22T00:16:09Z  terminating any restored/test instances tagged project=backup-lab...
2026-11-22T00:16:11Z  terminating instances: i-04759c1cffa43293c
2026-11-22T00:16:31Z  deleting backup recovery points from vault backup-lab-vault...
2026-11-22T00:16:33Z    deleting recovery point arn:aws:ec2:us-east-1::image/ami-051b1adf907ba1fab
2026-11-22T00:16:34Z  checking for unattached EBS volumes...
2026-11-22T00:16:36Z    deleting volume vol-073770e081f8b65ab
2026-11-22T00:16:39Z  running terraform destroy on AWS infrastructure...
2026-11-22T00:16:53Z  running audit to confirm complete removal...
2026-11-22T00:17:06Z  results written to /c/Users/Ricci/Documents/GitHub/cloud-portfolio/04-backup-and-restore/tests/results/20261121T230347Z-aws/results.json
2026-11-22T00:17:06Z  === Session Finished (exit code: 0) ===
