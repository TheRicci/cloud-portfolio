resource "azurerm_monitor_action_group" "alerts" {
  name                = "ag-${var.name_prefix}"
  resource_group_name = azurerm_resource_group.this.name
  short_name          = "obsalert"

  email_receiver {
    name                    = "session-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_metric_alert" "high_cpu" {
  name                = "alert-${var.name_prefix}-high-cpu"
  resource_group_name = azurerm_resource_group.this.name
  scopes              = [azurerm_linux_virtual_machine.vm.id]
  description         = "The Azure VM CPU average is above 80 percent. Check VM load first."
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.alerts.id
  }
}

