output "resource_group_name" {
  description = "Azure Resource Group name."
  value       = azurerm_resource_group.this.name
}

output "vm_name" {
  description = "Azure VM name."
  value       = azurerm_linux_virtual_machine.vm.name
}

output "vm_id" {
  description = "Azure VM resource ID."
  value       = azurerm_linux_virtual_machine.vm.id
}

output "public_ip" {
  description = "Static public IP assigned to the VM NIC."
  value       = azurerm_public_ip.vm.ip_address
}

output "alert_email" {
  description = "Configured alert email recipient."
  value       = var.alert_email
}

output "azure_run_demo_command" {
  description = "Run the demo scenarios directly on Azure via Azure Run Command (no open inbound ports needed)."
  value       = "az vm run-command invoke --resource-group ${azurerm_resource_group.this.name} --name ${azurerm_linux_virtual_machine.vm.name} --command-id RunShellScript --scripts '/opt/observability/demo.sh status'"
}
