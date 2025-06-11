resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = "${var.project_name}-rg"
}

# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = "${var.project_name}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "${var.project_name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "my_terraform_public_ip" {
  name                = "${var.project_name}-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rules
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "${var.project_name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
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
}

# Create network interface
resource "azurerm_network_interface" "my_terraform_nic" {
  name                = "${var.project_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.my_terraform_nic.id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
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

resource "azurerm_key_vault" "kv" {
    name                            =       "${var.project_name}--kv"
    resource_group_name             =       azurerm_resource_group.rg.name
    location                        =       azurerm_resource_group.rg.location
    enabled_for_deployment          =       true
    enabled_for_disk_encryption     =       true
    tenant_id                       =       data.azurerm_client_config.current.tenant_id
    sku_name                        =       "standard"

    access_policy  {
        tenant_id                   =       data.azurerm_client_config.current.tenant_id
        object_id                   =       data.azurerm_client_config.current.object_id
        key_permissions             =       local.kv_key_permissions
        secret_permissions          =       local.kv_secret_permissions
    }
}

resource "azurerm_key_vault_secret" "kv" {
    for_each                        =       var.kv_secrets
    name                            =       each.key
    key_vault_id                    =       azurerm_key_vault.kv.id
    value                           =       each.value
}

resource "azurerm_key_vault_key" "kv" {
    name                            =       "${var.project_name}-vm-ade-kek"
    key_vault_id                    =       azurerm_key_vault.kv.id
    key_type                        =       "RSA"
    key_size                        =       2048
    key_opts                        =       ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey",]
}

resource "azurerm_key_vault_key" "kv-admin" {
    name                            =       "${var.project_name}-vm-admin-kek"
    key_vault_id                    =       azurerm_key_vault.kv.id
    key_type                        =       "RSA"
    key_size                        =       2048
    key_opts                        =       ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey",]
}


resource "azurerm_linux_virtual_machine" "vm" {
    name                              =     "${var.project_name}-linux-vm"
    resource_group_name               =     azurerm_resource_group.rg.name
    location                          =     azurerm_resource_group.rg.location
    network_interface_ids             =     [azurerm_network_interface.my_terraform_nic.id]
    size                              =     "Standard_DS1_v2"
    computer_name                     =     "linux-vm"
    admin_username                    =     azurerm_key_vault_secret.kv["linuxvm-username"].value
    admin_ssh_key                     =     azurerm_key_vault_key.kv-admin.public
    disable_password_authentication   =     false
    allow_extension_operations        =     true

    os_disk  {
        name                          =     "${var.project_name}-vm-os-disk"
        caching                       =     "ReadWrite"
        storage_account_type          =     "StandardSSD_LRS"
        disk_size_gb                  =     64
    }

    source_image_reference {
        publisher                     =     "Canonical"
        offer                         =     "UbuntuServer"
        sku                           =     "16.04-LTS"
        version                       =     "latest"
    }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

#resource "random_password" "password" {
#  length      = 20
#  min_lower   = 1
#  min_upper   = 1
#  min_numeric = 1
#  min_special = 1
#  special     = true
#}

resource "azurerm_recovery_services_vault" "example" {
  name                = "${var.project_name}-vault"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"
  soft_delete_enabled = var.soft_delete_enabled
}

resource "azurerm_backup_policy_vm" "example" {
  name                = "${var.project_name}-policy"
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.example.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 7
  }
}

resource "azurerm_backup_protected_vm" "example" {
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.example.name
  source_vm_id        = azurerm_windows_virtual_machine.main.id
  backup_policy_id    = azurerm_backup_policy_vm.example.id
}
