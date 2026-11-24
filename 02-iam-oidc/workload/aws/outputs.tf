output "instance_id" {
  description = "ID of the deployed showcase EC2 instance."
  value       = aws_instance.showcase_vm.id
}

output "instance_private_ip" {
  description = "Private IP address of the showcase VM."
  value       = aws_instance.showcase_vm.private_ip
}

output "deployed_by_arn" {
  description = "IAM identity ARN that deployed this showcase infrastructure (proves OIDC role assumption)."
  value       = data.aws_caller_identity.current.arn
}

output "vpc_id" {
  description = "VPC ID of the showcase network."
  value       = aws_vpc.showcase.id
}
