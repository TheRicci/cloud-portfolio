output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.vm.id
}

output "region" {
  description = "AWS region."
  value       = var.region
}

output "bucket_name" {
  description = "S3 bucket name."
  value       = aws_s3_bucket.this.id
}

output "backup_vault_name" {
  description = "AWS Backup vault name."
  value       = aws_backup_vault.this.name
}

output "backup_service_role_arn" {
  description = "IAM role ARN for AWS Backup."
  value       = aws_iam_role.backup.arn
}

output "limited_role_arn" {
  description = "IAM role ARN for Drill D (limited permissions)."
  value       = aws_iam_role.limited.arn
}

output "data_volume_id" {
  description = "EBS data volume ID."
  value       = aws_ebs_volume.data.id
}

output "instance_arn" {
  description = "EC2 instance ARN."
  value       = aws_instance.vm.arn
}
