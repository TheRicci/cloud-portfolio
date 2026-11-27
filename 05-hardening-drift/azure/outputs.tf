output "public_ip" {
  value = azurerm_public_ip.lab.ip_address
}

output "ssh_user" {
  value = "azureuser"
}
