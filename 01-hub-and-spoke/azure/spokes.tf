# ============================================================
# Spoke VNets, Peering, UDRs, NSGs, Test VMs
# ============================================================

# ── Spoke 1 VNet ─────────────────────────────────────────────────────────────

resource "azurerm_virtual_network" "spoke1" {
  name                = "vnet-spoke1-${var.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.spoke1_address_space]
  tags                = azurerm_resource_group.main.tags
}

resource "azurerm_subnet" "spoke1" {
  name                 = "snet-spoke1"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  address_prefixes     = [var.spoke1_subnet_prefix]
}

# ── Spoke 2 VNet ─────────────────────────────────────────────────────────────

resource "azurerm_virtual_network" "spoke2" {
  name                = "vnet-spoke2-${var.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.spoke2_address_space]
  tags                = azurerm_resource_group.main.tags
}

resource "azurerm_subnet" "spoke2" {
  name                 = "snet-spoke2"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke2.name
  address_prefixes     = [var.spoke2_subnet_prefix]
}

# ── VNet Peering: Hub ↔ Spoke1 ───────────────────────────────────────────────
# allow_forwarded_traffic: hub can forward packets that didn't originate in hub
# allow_gateway_transit:   spokes can use hub VPN/ExpressRoute (future-proofing)
# use_remote_gateways:     spoke side uses the hub's gateway

resource "azurerm_virtual_network_peering" "hub_to_spoke1" {
  name                      = "peer-hub-to-spoke1"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke1.id

  allow_forwarded_traffic = true
  allow_gateway_transit   = true
  use_remote_gateways     = false
}

resource "azurerm_virtual_network_peering" "spoke1_to_hub" {
  name                      = "peer-spoke1-to-hub"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.spoke1.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_forwarded_traffic = true
  allow_gateway_transit   = false
  use_remote_gateways     = false

  depends_on = [azurerm_virtual_network_peering.hub_to_spoke1]
}

# ── VNet Peering: Hub ↔ Spoke2 ───────────────────────────────────────────────

resource "azurerm_virtual_network_peering" "hub_to_spoke2" {
  name                      = "peer-hub-to-spoke2"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke2.id

  allow_forwarded_traffic = true
  allow_gateway_transit   = true
  use_remote_gateways     = false
}

resource "azurerm_virtual_network_peering" "spoke2_to_hub" {
  name                      = "peer-spoke2-to-hub"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.spoke2.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_forwarded_traffic = true
  allow_gateway_transit   = false
  use_remote_gateways     = false

  depends_on = [azurerm_virtual_network_peering.hub_to_spoke2]
}

# ── UDR: Force inter-spoke traffic through the NVA ───────────────────────────
# Only the remote spoke CIDR is routed to the appliance. This keeps the
# project's inspection boundary explicit and avoids treating general egress as
# an accidental side effect of a test topology.

resource "azurerm_route_table" "spoke1" {
  name                          = "rt-spoke1-${var.prefix}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  disable_bgp_route_propagation = true

  route {
    name                   = "route-spoke2-via-nva"
    address_prefix         = var.spoke2_address_space
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.nva.private_ip_address
  }

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_subnet_route_table_association" "spoke1" {
  subnet_id      = azurerm_subnet.spoke1.id
  route_table_id = azurerm_route_table.spoke1.id
}

resource "azurerm_route_table" "spoke2" {
  name                          = "rt-spoke2-${var.prefix}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  disable_bgp_route_propagation = true

  route {
    name                   = "route-spoke1-via-nva"
    address_prefix         = var.spoke1_address_space
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_network_interface.nva.private_ip_address
  }

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_subnet_route_table_association" "spoke2" {
  subnet_id      = azurerm_subnet.spoke2.id
  route_table_id = azurerm_route_table.spoke2.id
}

# ── Spoke NSGs ───────────────────────────────────────────────────────────────
# No inbound from internet. No public IPs on spoke VMs. Inter-spoke traffic
# reaches the VMs only after being forwarded by the NVA.

resource "azurerm_network_security_group" "spoke1" {
  name                = "nsg-spoke1-${var.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "deny-inbound-internet"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_subnet_network_security_group_association" "spoke1" {
  subnet_id                 = azurerm_subnet.spoke1.id
  network_security_group_id = azurerm_network_security_group.spoke1.id
}

resource "azurerm_network_security_group" "spoke2" {
  name                = "nsg-spoke2-${var.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "deny-inbound-internet"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_subnet_network_security_group_association" "spoke2" {
  subnet_id                 = azurerm_subnet.spoke2.id
  network_security_group_id = azurerm_network_security_group.spoke2.id
}

# ── Spoke Test VMs ───────────────────────────────────────────────────────────
# No public IPs. Access via az vm run-command invoke only.
# Spoke1 = "compromised attacker" in security audit.
# Spoke2 = "target".

resource "azurerm_network_interface" "spoke1_vm" {
  name                = "nic-spoke1-vm-${var.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig-spoke1-vm"
    subnet_id                     = azurerm_subnet.spoke1.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.1.1.4"
  }

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_linux_virtual_machine" "spoke1_vm" {
  name                            = "vm-spoke1-${var.prefix}"
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.spoke1_vm.id]

  # A deliberately small workload makes the network acceptance test real.
  # Python 3 ships with the Ubuntu image; no package download is required.
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    nohup python3 -m http.server 8443 --bind 0.0.0.0 >/var/log/test-service.log 2>&1 &
  EOF
  )

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

  tags = merge(azurerm_resource_group.main.tags, { role = "attacker-spoke1" })
}

resource "azurerm_network_interface" "spoke2_vm" {
  name                = "nic-spoke2-vm-${var.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "ipconfig-spoke2-vm"
    subnet_id                     = azurerm_subnet.spoke2.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.2.1.4"
  }

  tags = azurerm_resource_group.main.tags
}

resource "azurerm_linux_virtual_machine" "spoke2_vm" {
  name                            = "vm-spoke2-${var.prefix}"
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.spoke2_vm.id]

  custom_data = base64encode(<<-EOF
    #!/bin/bash
    nohup python3 -m http.server 8443 --bind 0.0.0.0 >/var/log/test-service.log 2>&1 &
  EOF
  )

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

  tags = merge(azurerm_resource_group.main.tags, { role = "target-spoke2" })
}
