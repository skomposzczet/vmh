output "public_ip_address_jump" {
  value = azurerm_linux_virtual_machine.jump.public_ip_address
}

output "ssh_key" {
  sensitive = true
  value     = tls_private_key.kv_admin
}
