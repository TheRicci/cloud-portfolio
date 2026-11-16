# ============================================================
# Resource Group
# ============================================================

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.prefix}"
  location = var.location

  tags = {
    project     = "cloud-portfolio"
    sub-project = "01-hub-and-spoke"
    managed-by  = "terraform"
    session     = "azure-01"
  }
}

# ============================================================
# Hub VNet
# ============================================================

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-${var.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.hub_address_space]

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_subnet" "hub" {
  name                 = "snet-hub"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_subnet_prefix]
}

# ============================================================
# Hub NSG — attached to hub subnet
# Allows forwarded spoke traffic through the NVA while keeping its management
# port inaccessible from workload spokes. The lower priority number wins.
# ============================================================

resource "azurerm_network_security_group" "hub" {
  name                = "nsg-hub-${var.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Deny SSH into NVA from spoke ranges before the transit allow rule.
  security_rule {
    name                       = "deny-ssh-to-nva-from-spokes"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = [var.spoke1_address_space, var.spoke2_address_space]
    destination_address_prefix = var.hub_subnet_prefix
  }

  # Permit transit packets to reach the NVA. Stateful protocol policy is
  # enforced by the NVA itself; this NSG is not the inspection layer.
  security_rule {
    name                       = "allow-transit-from-spokes"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = [var.spoke1_address_space, var.spoke2_address_space]
    destination_address_prefix = "*"
  }

  # Deny all other inbound (internet, etc.)
  security_rule {
    name                       = "deny-all-other-inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_subnet_network_security_group_association" "hub" {
  subnet_id                 = azurerm_subnet.hub.id
  network_security_group_id = azurerm_network_security_group.hub.id
}

# ============================================================
# NVA — Ubuntu B1s with IP forwarding enabled
# iptables policy applied via cloud-init (nva-init.sh)
# Policy is secure-by-default — see docs/security-model.md
# ============================================================

resource "azurerm_network_interface" "nva" {
  name                = "nic-nva-${var.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # IP forwarding must be enabled at the Azure NIC level
  # so Azure passes packets not addressed to this VM's IP
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "ipconfig-nva"
    subnet_id                     = azurerm_subnet.hub.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.4"
  }

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_linux_virtual_machine" "nva" {
  name                            = "vm-nva-${var.prefix}"
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.nva.id]

  # cloud-init applies iptables rules and enables ip_forward on boot
  custom_data = filebase64("${path.module}/nva-init.sh")

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = azurerm_resource_group.main.tags
}
