data "azurerm_client_config" "current" {}

# Minimal isolated VNet and Subnet inside the deployment Resource Group
resource "azurerm_virtual_network" "showcase" {
  name                = "vnet-oidc-showcase"
  address_space       = ["10.43.0.0/24"]
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_subnet" "showcase" {
  name                 = "snet-oidc-showcase"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.showcase.name
  address_prefixes     = ["10.43.0.0/28"]
}

resource "azurerm_network_interface" "showcase" {
  name                = "nic-oidc-showcase"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.showcase.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    Environment = var.environment
  }
}

resource "azurerm_linux_virtual_machine" "showcase" {
  name                = "vm-oidc-showcase"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"

  disable_password_authentication = true
  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+5n3J5r+G4LcQigQxBV0YTaGLh8IqOB/p7hPbIXpq8BuAoM7UZSXebkGnfXblzSQlRq1rTY6tDCxy7caPNqCbC7Dqfg6V5J8FlkNvuLf7r/Tj49gRYZBA1dbgmQ42N9mmAQtvDdpEZWA0oAijzPWyz5A6NgsAe2uOKkw2FnDJWr/eiB9x6y8OKe7j4jMY/G17hOq+xeqCkxxvxQnJKThlzuq8eaDN43IFYbMgPoEztmrmiSVnzw9n0XEr+UI+Il1okjHRT8KnISk8Dgrw5nkPFHg53vntkGYcYNXI7BC2eGFT9QDMHH7dvV91SUnDccfiK6fyg0kES24VR/nksa1D oidc-showcase-demo"
  }

  network_interface_ids = [
    azurerm_network_interface.showcase.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    Environment = var.environment
    DeployedBy  = data.azurerm_client_config.current.client_id
  }
}
