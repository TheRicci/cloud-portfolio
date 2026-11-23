# --- Data disk for Postgres ---

resource "azurerm_managed_disk" "data" {
  name                 = "disk-${var.name_prefix}-data"
  location             = azurerm_resource_group.this.location
  resource_group_name  = azurerm_resource_group.this.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 4

  tags = {
    Lab       = "04-backup-and-restore"
    ManagedBy = "Terraform"
    project   = "backup-lab"
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  managed_disk_id    = azurerm_managed_disk.data.id
  virtual_machine_id = azurerm_linux_virtual_machine.vm.id
  lun                = 1
  caching            = "None"
}

# --- Linux VM ---

resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "vm-${var.name_prefix}"
  computer_name                   = "backup-vm"
  location                        = azurerm_resource_group.this.location
  resource_group_name             = azurerm_resource_group.this.name
  size                            = var.vm_size
  admin_username                  = "backuplab"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.vm.id]

  custom_data = base64encode(templatefile("${path.module}/../workload/cloud-init.yaml.tftpl", {
    data_disk_device = "/dev/disk/azure/scsi1/lun1"
    writer_go_source = file("${path.module}/../workload/writer/main.go")
    writer_go_mod    = file("${path.module}/../workload/writer/go.mod")
    writer_go_sum    = file("${path.module}/../workload/writer/go.sum")
    cli_install_cmd  = "curl -sL https://aka.ms/InstallAzureCLIDeb | bash"
  }))

  admin_ssh_key {
    username   = "backuplab"
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 8
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Lab       = "04-backup-and-restore"
    ManagedBy = "Terraform"
    project   = "backup-lab"
  }

  depends_on = [azurerm_network_interface_security_group_association.vm]
}
