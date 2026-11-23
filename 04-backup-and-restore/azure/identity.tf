# --- VM system-assigned identity: storage access ---

resource "azurerm_role_assignment" "vm_blob" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id
}

# --- Limited identity for Drill D ---

resource "azurerm_user_assigned_identity" "limited" {
  name                = "${var.name_prefix}-limited"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_role_definition" "limited" {
  name        = "${var.name_prefix}-limited-role"
  scope       = azurerm_resource_group.this.id
  description = "Can restart VMs but cannot touch backup items or the vault."

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/read",
    ]
    not_actions = [
      "Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems/delete",
      "Microsoft.RecoveryServices/vaults/delete",
    ]
  }

  assignable_scopes = [azurerm_resource_group.this.id]
}

resource "azurerm_role_assignment" "limited" {
  scope              = azurerm_resource_group.this.id
  role_definition_id = azurerm_role_definition.limited.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.limited.principal_id
}
