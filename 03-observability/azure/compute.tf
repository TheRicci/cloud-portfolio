resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "vm-${var.name_prefix}"
  computer_name                   = "obs-vm"
  location                        = azurerm_resource_group.this.location
  resource_group_name             = azurerm_resource_group.this.name
  size                            = var.vm_size
  admin_username                  = "observer"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.vm.id]
  custom_data                     = base64encode(local.cloud_init)

  admin_ssh_key {
    username   = "observer"
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  tags = {
    Project   = "03-observability"
    ManagedBy = "Terraform"
  }

  depends_on = [azurerm_network_interface_security_group_association.vm]
}
