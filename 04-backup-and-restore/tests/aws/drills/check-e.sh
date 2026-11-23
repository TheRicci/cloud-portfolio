#!/usr/bin/env bash
# Check E — Scripted restore testing on AWS. Sourced by tests/aws/run.sh.

run_check_e() {
  local start
  start="$(timer_start)"

  note "running scripted AWS restore test..."

  local recovery_point_arn
  recovery_point_arn="$(aws backup list-recovery-points-by-backup-vault \
    --region "$AWS_REGION" \
    --backup-vault-name "$VAULT_NAME" \
    --query 'RecoveryPoints | sort_by(@, &CreationDate) | [-1].RecoveryPointArn' \
    --output text)"
  note "restore test from: $recovery_point_arn"

  local sg_id subnet_id profile_name orig_metadata restore_metadata test_job_id
  sg_id="$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters Name=tag:project,Values=backup-lab --query 'SecurityGroups[0].GroupId' --output text)"
  subnet_id="$(aws ec2 describe-subnets --region "$AWS_REGION" --filters Name=tag:project,Values=backup-lab --query 'Subnets[0].SubnetId' --output text)"
  profile_name="$(aws iam list-instance-profiles --query "InstanceProfiles[?contains(InstanceProfileName,'backup-lab')].InstanceProfileName | [0]" --output text)"

  orig_metadata="$(aws backup get-recovery-point-restore-metadata \
    --region "$AWS_REGION" \
    --backup-vault-name "$VAULT_NAME" \
    --recovery-point-arn "$recovery_point_arn" \
    --query 'RestoreMetadata' --output json 2>/dev/null || echo '{}')"

  restore_metadata="$(echo "$orig_metadata" | jq -c \
    --arg sg "[\"$sg_id\"]" \
    --arg subnet "$subnet_id" \
    --arg profile_name "$profile_name" \
    'del(.NetworkInterfaces, .IamInstanceProfileArn) |
     .SubnetId = $subnet |
     .SecurityGroupIds = $sg |
     .IamInstanceProfileName = $profile_name |
     .InstanceType = (.InstanceType // "t3.micro")')"

  test_job_id="$(aws backup start-restore-job \
    --region "$AWS_REGION" \
    --recovery-point-arn "$recovery_point_arn" \
    --iam-role-arn "$BACKUP_ROLE_ARN" \
    --metadata "$restore_metadata" \
    --query RestoreJobId --output text)"
  note "restore test job: $test_job_id"

  wait_restore_aws "$test_job_id" 900 || {
    fail "check-e" "restore test job failed"
    return 1
  }

  local test_instance_id
  test_instance_id="$(aws backup describe-restore-job \
    --region "$AWS_REGION" \
    --restore-job-id "$test_job_id" \
    --query CreatedResourceArn --output text | grep -oE 'i-[a-f0-9]+')"
  note "test instance: $test_instance_id"

  aws ec2 create-tags \
    --region "$AWS_REGION" \
    --resources "$test_instance_id" \
    --tags Key=project,Value=backup-lab Key=session_id,Value="$RUN_ID" Key=Name,Value=backup-lab-test

  note "cleaning up test instance: $test_instance_id..."
  aws ec2 terminate-instances \
    --region "$AWS_REGION" \
    --instance-ids "$test_instance_id" \
    --output text >/dev/null

  local elapsed
  elapsed="$(timer_elapsed "$start")"
  pass "check-e" "AWS restore test completed in ${elapsed}s"
}
