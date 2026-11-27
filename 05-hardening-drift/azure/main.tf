locals {
  user_data = templatefile("${path.module}/../common/cloud-init.yaml.tftpl", {
    repo_url           = var.repo_url
    repo_sha           = var.repo_sha
    project_dir        = var.project_dir
    pull_interval_min  = var.pull_interval_min
    weak_baseline      = var.weak_baseline
    ansible_bundle_b64 = var.ansible_bundle_b64
  })

  tags = {
    project = "hardening-lab"
    session = var.session_id
  }
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-hardening-lab"
  location = var.region
  tags     = local.tags
}

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-hardening-lab"
  address_space       = ["10.78.0.0/24"]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_subnet" "lab" {
  name                 = "snet-hardening-lab"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.78.0.0/25"]
}

resource "azurerm_network_security_group" "lab" {
  name                = "nsg-hardening-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags

  security_rule {
    name                       = "ssh-and-decoy-from-tester"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "8080"]
    source_address_prefix      = var.allowed_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "lab" {
  name                = "pip-hardening-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "lab" {
  name                = "nic-hardening-lab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.lab.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.lab.id
  }
}

resource "azurerm_network_interface_security_group_association" "lab" {
  network_interface_id      = azurerm_network_interface.lab.id
  network_security_group_id = azurerm_network_security_group.lab.id
}

resource "azurerm_linux_virtual_machine" "lab" {
  name                            = "vm-hardening-lab"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  size                            = var.vm_size
  admin_username                  = "azureuser"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.lab.id]
  custom_data                     = base64encode(local.user_data)
  tags                            = local.tags

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
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
}
