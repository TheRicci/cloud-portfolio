output "nva_private_ip" {
  description = "Private IP of the hub NVA. Used as next-hop in spoke UDRs."
  value       = azurerm_network_interface.nva.private_ip_address
}

output "spoke1_vm_private_ip" {
  description = "Private IP of the Spoke 1 test VM."
  value       = azurerm_network_interface.spoke1_vm.private_ip_address
}

output "spoke2_vm_private_ip" {
  description = "Private IP of the Spoke 2 test VM."
  value       = azurerm_network_interface.spoke2_vm.private_ip_address
}

output "resource_group_name" {
  description = "Resource group containing all resources. Use to scope CLI commands."
  value       = azurerm_resource_group.main.name
}

output "spoke1_vm_name" {
  description = "Name of the Spoke 1 VM. Used in az vm run-command invoke."
  value       = azurerm_linux_virtual_machine.spoke1_vm.name
}

output "spoke2_vm_name" {
  description = "Name of the Spoke 2 VM. Used in az vm run-command invoke."
  value       = azurerm_linux_virtual_machine.spoke2_vm.name
}

output "nva_vm_name" {
  description = "Name of the NVA VM."
  value       = azurerm_linux_virtual_machine.nva.name
}
