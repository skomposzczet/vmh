resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = "${var.project_name}-rg"
}

#Virtual Network
resource "azurerm_virtual_network" "network" {
  name                = "${var.project_name}-vnet"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

#Subnet
resource "azurerm_subnet" "subnet_fire_wall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = ["10.10.0.0/26"]
}

#Subnet
resource "azurerm_subnet" "subnet_vm" {
  name                 = "${var.project_name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = ["10.10.1.0/24"]
}

#Subnet
resource "azurerm_subnet" "subnet_jump" {
  name                 = "${var.project_name}-subnet-jump"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.network.name
  address_prefixes     = ["10.10.2.0/24"]
}


# Public IPs
resource "azurerm_public_ip" "firewall_public_ip" {
  name                = "${var.project_name}-firewall-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Public IPs
resource "azurerm_public_ip" "jump_public_ip" {
  name                = "${var.project_name}-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# resource "azurerm_public_ip" "nic_public_ip" {
#   name                = "poc-nic-public-ip"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   allocation_method   = "Static"
#   sku                 = "Standard"
# }

# Active User Ip
data "http" "user_ip" {
  url = "https://api.ipify.org/"
}

# Create network interface
resource "azurerm_network_interface" "vm_nic" {
  name                = "${var.project_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.subnet_vm.id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = azurerm_public_ip.nic_public_ip.id
  }
}

resource "azurerm_network_interface" "jump_nic" {
  name                = "${var.project_name}-nic-jump"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.subnet_vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jump_public_ip.id
  }
}

# Network Security Group + rules
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "${var.project_name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "ssh"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "jump_nsg" {
  name                = "${var.project_name}-nsg-jump"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "ssh"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = chomp(data.http.user_ip.response_body)
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "sshout"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "10.10.1.5"
  }
}

resource "azurerm_network_interface_security_group_association" "vm_nic_nsg" {
  network_interface_id      = azurerm_network_interface.vm_nic.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

resource "azurerm_network_interface_security_group_association" "jump_nic_nsg" {
  network_interface_id      = azurerm_network_interface.jump_nic.id
  network_security_group_id = azurerm_network_security_group.jump_nsg.id
}

#Firewall Policy
resource "azurerm_firewall_policy" "region1-fw-pol01" {
  name                = "region1-firewall-policy01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.resource_group_location
}

# Firewall Policy Rules
resource "azurerm_firewall_policy_rule_collection_group" "region1-policy1" {
  name               = "region1-policy1"
  firewall_policy_id = azurerm_firewall_policy.region1-fw-pol01.id
  priority           = 100

  application_rule_collection {
    name     = "blocked_websites1"
    priority = 500
    action   = "Deny"
    rule {
      name = "dodgy_website"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*"]
    }
  }

  application_rule_collection {
    name     = "allowed_websites"
    priority = 200
    action   = "Allow"
    dynamic "rule" {
      for_each = var.allowed_sites
      content {
        name = "cool_website_${rule.value.name}"
        protocols {
          type = "Http"
          port = 80
        }
        protocols {
          type = "Https"
          port = 443
        }
        source_addresses  = ["*"]
        destination_fqdns = ["${rule.value.ip}"]
      }
    }
  }

  nat_rule_collection {
    name     = "AllowSSH"
    priority = 100
    action   = "Dnat"
    rule {
      name = "AllowSSH"
      source_addresses    = ["108.142.232.35"]
      protocols           = ["TCP"]
      destination_ports   = ["22"]
      destination_address = azurerm_public_ip.firewall_public_ip.ip_address
      translated_port     = 22
      translated_address  = azurerm_network_interface.vm_nic.private_ip_address
    }
  }
}
#Azure Firewall Instance
resource "azurerm_firewall" "region1-fw01" {
  name                = "region1-fw01"
  location            = var.resource_group_location
  resource_group_name = azurerm_resource_group.rg.name
  sku_tier            = "Premium"
  sku_name            = "AZFW_VNet"
  firewall_policy_id  = azurerm_firewall_policy.region1-fw-pol01.id
  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.subnet_fire_wall.id
    public_ip_address_id = azurerm_public_ip.firewall_public_ip.id
  }
}

resource "azurerm_route_table" "rt" {
  name                = "${var.project_name}-route-table"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  route {
    name                   = "rout1"
    address_prefix          = "10.10.1.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.region1-fw01.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "sn_rt_as" {
  subnet_id      = azurerm_subnet.subnet_vm.id
  route_table_id = azurerm_route_table.rt.id
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

data "azurerm_client_config" "current" {}

resource "random_integer" "random" {
  min = 11111
  max = 99999
}

# resource "azurerm_key_vault" "kv" {
#   name                        = "${var.project_name}-kv${random_integer.random.result}"
#   resource_group_name         = azurerm_resource_group.rg.name
#   location                    = azurerm_resource_group.rg.location
#   enabled_for_deployment      = true
#   enabled_for_disk_encryption = true
#   tenant_id                   = data.azurerm_client_config.current.tenant_id
#   sku_name                    = "standard"
#   access_policy {
#     tenant_id = data.azurerm_client_config.current.tenant_id
#     object_id = data.azurerm_client_config.current.object_id
#     key_permissions = [
#       "Create",
#       "Delete",
#       "Get",
#       "Purge",
#       "Recover",
#       "Update",
#       "GetRotationPolicy",
#       "SetRotationPolicy"
#     ]
#     secret_permissions = [
#       "Set",
#     ]
#   }
# }
#
# resource "azurerm_key_vault_key" "kv" {
#   name         = "${var.project_name}-vm-ade-kek"
#   key_vault_id = azurerm_key_vault.kv.id
#   key_type     = "RSA"
#   key_size     = 2048
#   key_opts = [
#     "decrypt",
#     "encrypt",
#     "sign",
#     "unwrapKey",
#     "verify",
#     "wrapKey",
#   ]
#   rotation_policy {
#     automatic {
#       time_before_expiry = "P30D"
#     }
#     expire_after         = "P90D"
#     notify_before_expiry = "P29D"
#   }
# }

resource "tls_private_key" "kv_admin" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content  = tls_private_key.kv_admin.private_key_pem
  filename = pathexpand("./.ssh/vm1")
  file_permission = "0400"
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "${var.project_name}-linux-vm"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  network_interface_ids           = [azurerm_network_interface.vm_nic.id]
  size                            = "Standard_D2s_v3"
  computer_name                   = "linux-vm"
  admin_username                  = "azureuser"
  admin_password = "Admin1!"
  disable_password_authentication = false
  allow_extension_operations      = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.kv_admin.public_key_openssh
  }

  os_disk {
    name                 = "${var.project_name}-vm-os-disk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}

resource "azurerm_linux_virtual_machine" "jump" {
  name                            = "${var.project_name}-linux-jump"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  network_interface_ids           = [azurerm_network_interface.jump_nic.id]
  size                            = "Standard_D2s_v3"
  computer_name                   = "linux-vm"
  admin_username                  = "azureuser"
  admin_password = "Admin1!"
  disable_password_authentication = false
  allow_extension_operations      = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.kv_admin.public_key_openssh
  }

  os_disk {
    name                 = "${var.project_name}-vm-os-disk-jump"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  # boot_diagnostics {
  #   storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  # }
}


# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    resource_group = azurerm_resource_group.rg.name
  }
  byte_length = 8
}

# resource "azurerm_virtual_machine_extension" "linux-ade" {
#   name                       = "AzureDiskEncryption"
#   virtual_machine_id         = azurerm_linux_virtual_machine.vm.id
#   publisher                  = "Microsoft.Azure.Security"
#   type                       = "AzureDiskEncryptionForLinux"
#   type_handler_version       = "1.1"
#   auto_upgrade_minor_version = true
#
#   settings   = <<SETTINGS
#   {
#   "EncryptionOperation"         :     "EnableEncryption",
#   "KeyVaultURL"                 :     "${azurerm_key_vault.kv.vault_uri}",
#   "KeyVaultResourceId"          :     "${azurerm_key_vault.kv.id}",
#   "KeyEncryptionKeyURL"         :     "${azurerm_key_vault_key.kv.id}",
#   "KekVaultResourceId"          :     "${azurerm_key_vault.kv.id}",
#   "KeyEncryptionAlgorithm"      :     "RSA-OAEP",
#   "VolumeType"                  :     "All"
#   }
#   SETTINGS
#   depends_on = [azurerm_linux_virtual_machine.vm]
# }
#
# resource "azurerm_recovery_services_vault" "example" {
#   name                = "${var.project_name}-vault"
#   resource_group_name = azurerm_resource_group.rg.name
#   location            = azurerm_resource_group.rg.location
#   sku                 = "Standard"
#   soft_delete_enabled = var.soft_delete_enabled
# }
#
# resource "azurerm_backup_policy_vm" "example" {
#   name                = "${var.project_name}-policy"
#   resource_group_name = azurerm_resource_group.rg.name
#   recovery_vault_name = azurerm_recovery_services_vault.example.name
#   backup {
#     frequency = "Daily"
#     time      = "23:00"
#   }
#   retention_daily {
#     count = 7
#   }
# }
#
# resource "azurerm_backup_protected_vm" "example" {
#   resource_group_name = azurerm_resource_group.rg.name
#   recovery_vault_name = azurerm_recovery_services_vault.example.name
#   source_vm_id        = azurerm_linux_virtual_machine.vm.id
#   backup_policy_id    = azurerm_backup_policy_vm.example.id
# }
