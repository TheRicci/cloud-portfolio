output "instance_id" {
  description = "Unified Observability EC2 instance ID."
  value       = aws_instance.vm.id
}

output "region" {
  description = "AWS region deployed to."
  value       = var.region
}

output "cloudwatch_alarm_name" {
  description = "CloudWatch CPU alarm name."
  value       = aws_cloudwatch_metric_alarm.high_cpu.alarm_name
}

output "grafana_port_forward_command" {
  description = "Run this in your terminal to open Grafana on http://localhost:3000 via AWS SSM (no open ports needed)."
  value       = "aws ssm start-session --target ${aws_instance.vm.id} --region ${var.region} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"3000\"],\"localPortNumber\":[\"3000\"]}'"
}

output "ssm_shell_command" {
  description = "Run this to open an interactive root shell on the VM."
  value       = "aws ssm start-session --target ${aws_instance.vm.id} --region ${var.region}"
}

output "run_demo_command" {
  description = "Run the demo scenarios directly on the VM via SSM."
  value       = "aws ssm send-command --region ${var.region} --instance-ids ${aws_instance.vm.id} --document-name AWS-RunShellScript --parameters '{\"commands\":[\"/opt/observability/demo.sh status\"]}'"
}
