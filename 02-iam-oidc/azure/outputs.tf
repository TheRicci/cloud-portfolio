output "plan_client_id" {
  value = azuread_application.plan.client_id
}

output "apply_client_id" {
  value = azuread_application.apply.client_id
}

output "tenant_id" {
  value = data.azuread_client_config.current.tenant_id
}

output "subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
}
