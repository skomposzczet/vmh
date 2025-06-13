output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "azurerm_recovery_services_vault_name" {
  value = azurerm_recovery_services_vault.example.name
}

output "azurerm_backup_policy_vm_name" {
  value = azurerm_backup_policy_vm.example.name
}

output "azurerm_linux_virtual_machine_name" {
  value = azurerm_linux_virtual_machine.vm.name
}

output "public_ip_address" {
  value = azurerm_linux_virtual_machine.vm.public_ip_address
}

output "ssh_key" {
  sensitive = true
  value     = tls_private_key.kv_admin
}
