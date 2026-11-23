# --- Storage account for dumps and test files ---

resource "azurerm_storage_account" "this" {
  name                          = replace("${var.name_prefix}store", "-", "")
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  https_traffic_only_enabled    = true
  public_network_access_enabled = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }
  }

  tags = {
    Lab       = "04-backup-and-restore"
    ManagedBy = "Terraform"
    project   = "backup-lab"
  }
}

resource "azurerm_storage_container" "dumps" {
  name                  = "dumps"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "files" {
  name                  = "files"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}
