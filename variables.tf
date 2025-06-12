variable "resource_group_location" {
  type        = string
  default     = "West Europe"
  description = "Location of the resource group."
}

variable "soft_delete_enabled" {
  type        = bool
  default     = false
  nullable    = false
  description = "Is soft delete enable for the recovery services vault?"
}

variable "project_name"{
  type = string
  default = "poc"
  description = "General project name."
}

locals {
    kv_key_permissions      =       ["Create", "Delete", "Get", "List", "Import", "Encrypt", "Decrypt", "Recover", "WrapKey", "UnwrapKey", "Verify", "Sign", "Restore", "Purge", "Update", "Backup",]
    kv_secret_permissions   =       ["Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set",]
}

variable "allowed_sites" {
  type = list(object({
    name = string
    ip = string
  }))

  default = [
    {
      name = "bestiaZwadowic2137"
      ip = "janpawel2.pl"
    }
  ]
} 
