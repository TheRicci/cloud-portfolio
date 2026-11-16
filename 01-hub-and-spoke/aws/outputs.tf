output "transit_gateway_id" {
  description = "Transit Gateway ID."
  value       = aws_ec2_transit_gateway.main.id
}

output "spoke1_instance_id" {
  description = "Spoke 1 EC2 instance ID. Used in SSM send-command."
  value       = aws_instance.spoke1.id
}

output "spoke2_instance_id" {
  description = "Spoke 2 EC2 instance ID. Used in SSM send-command."
  value       = aws_instance.spoke2.id
}

output "spoke1_private_ip" {
  value = aws_instance.spoke1.private_ip
}

output "nva_instance_id" {
  description = "Inspection NVA instance ID."
  value       = aws_instance.nva.id
}

output "nva_private_ip" {
  description = "Private IP of the inspection NVA."
  value       = aws_instance.nva.private_ip
}

output "spoke2_private_ip" {
  value = aws_instance.spoke2.private_ip
}

output "hub_vpc_id" {
  value = aws_vpc.hub.id
}

output "spoke1_vpc_id" {
  value = aws_vpc.spoke1.id
}

output "spoke2_vpc_id" {
  value = aws_vpc.spoke2.id
}
