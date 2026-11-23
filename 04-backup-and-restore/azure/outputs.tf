output "resource_group_name" {
  description = "Azure resource group name."
  value       = azurerm_resource_group.this.name
}

output "vm_name" {
  description = "VM name."
  value       = azurerm_linux_virtual_machine.vm.name
}

output "vm_id" {
  description = "VM resource ID."
  value       = azurerm_linux_virtual_machine.vm.id
}

output "storage_account_name" {
  description = "Storage account name."
  value       = azurerm_storage_account.this.name
}

output "vault_name" {
  description = "Recovery Services vault name."
  value       = azurerm_recovery_services_vault.this.name
}

output "limited_identity_client_id" {
  description = "Client ID of the limited managed identity (Drill D)."
  value       = azurerm_user_assigned_identity.limited.client_id
}

output "limited_identity_id" {
  description = "Resource ID of the limited managed identity."
  value       = azurerm_user_assigned_identity.limited.id
}

output "location" {
  description = "Azure region."
  value       = var.location
}

output "subscription_id" {
  description = "Azure subscription ID."
  value       = data.azurerm_client_config.current.subscription_id
}
