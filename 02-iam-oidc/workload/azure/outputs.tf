output "vm_id" {
  description = "Resource ID of the showcase Azure VM."
  value       = azurerm_linux_virtual_machine.showcase.id
}

output "private_ip" {
  description = "Private IP address of the showcase VM."
  value       = azurerm_network_interface.showcase.ip_configuration[0].private_ip_address
}

output "deployed_by_client_id" {
  description = "Entra ID Client ID that deployed this showcase infrastructure (proves OIDC federated login)."
  value       = data.azurerm_client_config.current.client_id
}

output "vnet_id" {
  description = "Virtual Network ID of the showcase network."
  value       = azurerm_virtual_network.showcase.id
}
