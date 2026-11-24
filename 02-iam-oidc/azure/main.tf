data "azuread_client_config" "current" {}
data "azurerm_client_config" "current" {}

locals {
  github_oidc_issuer    = "https://token.actions.githubusercontent.com"
  github_oidc_audience  = "api://AzureADTokenExchange"
  state_container_scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.state_resource_group_name}/providers/Microsoft.Storage/storageAccounts/${var.state_storage_account_name}/blobServices/default/containers/${var.state_container_name}"
}

resource "azuread_application" "plan" {
  display_name = "id-portfolio-plan"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "plan" {
  client_id = azuread_application.plan.client_id
}

resource "azuread_application_federated_identity_credential" "plan" {
  application_id = azuread_application.plan.id
  display_name   = "github-azure-plan"
  description    = "Exact GitHub Actions trust for the azure-plan environment."
  audiences      = [local.github_oidc_audience]
  issuer         = local.github_oidc_issuer
  subject        = var.github_subject_plan
}

resource "azuread_application" "apply" {
  display_name = "id-portfolio-apply"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "apply" {
  client_id = azuread_application.apply.client_id
}

resource "azuread_application_federated_identity_credential" "apply" {
  application_id = azuread_application.apply.id
  display_name   = "github-azure-apply"
  description    = "Exact GitHub Actions trust for the azure-apply environment."
  audiences      = [local.github_oidc_audience]
  issuer         = local.github_oidc_issuer
  subject        = var.github_subject_apply
}

resource "azurerm_role_assignment" "plan_reader" {
  scope                            = var.deployment_resource_group_id
  role_definition_name             = "Reader"
  principal_id                     = azuread_service_principal.plan.object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "apply_contributor" {
  scope                            = var.deployment_resource_group_id
  role_definition_name             = "Contributor"
  principal_id                     = azuread_service_principal.apply.object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "plan_state" {
  scope                            = local.state_container_scope
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azuread_service_principal.plan.object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "apply_state" {
  scope                            = local.state_container_scope
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azuread_service_principal.apply.object_id
  skip_service_principal_aad_check = true
}
