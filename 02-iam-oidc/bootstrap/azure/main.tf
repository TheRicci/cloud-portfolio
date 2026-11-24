data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "terraform_state" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "terraform_state" {
  name                            = var.storage_account_name
  resource_group_name             = azurerm_resource_group.terraform_state.name
  location                        = azurerm_resource_group.terraform_state.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false

  blob_properties {
    versioning_enabled = true
  }
}

# Owner is a management-plane role and does not grant blob data access. This
# assignment lets the MFA-authenticated bootstrap operator create and later
# migrate the private state container without enabling storage account keys.
resource "azurerm_role_assignment" "bootstrap_operator_state" {
  scope                            = azurerm_storage_account.terraform_state.id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = data.azurerm_client_config.current.object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_storage_container" "terraform_state" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.terraform_state.name
  container_access_type = "private"

  depends_on = [azurerm_role_assignment.bootstrap_operator_state]
}
