# --- Recovery Services vault ---

resource "azurerm_recovery_services_vault" "this" {
  name                = "rsv-${var.name_prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  storage_mode_type   = "LocallyRedundant"

  # Soft delete is enforced by Azure ("Secure by Default") and cannot be
  # disabled. The teardown script purges soft-deleted items before deleting
  # the vault. Setting it explicitly avoids a plan diff.
  soft_delete_enabled = true

  tags = {
    Lab       = "04-backup-and-restore"
    ManagedBy = "Terraform"
    project   = "backup-lab"
  }
}

# --- Backup policy: daily, 1-day retention ---

resource "azurerm_backup_policy_vm" "this" {
  name                = "${var.name_prefix}-policy"
  resource_group_name = azurerm_resource_group.this.name
  recovery_vault_name = azurerm_recovery_services_vault.this.name

  timezone = "UTC"

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 1
  }

  instant_restore_retention_days = 1
}

# --- Protect the VM ---

resource "azurerm_backup_protected_vm" "this" {
  resource_group_name = azurerm_resource_group.this.name
  recovery_vault_name = azurerm_recovery_services_vault.this.name
  source_vm_id        = azurerm_linux_virtual_machine.vm.id
  backup_policy_id    = azurerm_backup_policy_vm.this.id

  depends_on = [azurerm_virtual_machine_data_disk_attachment.data]
}
