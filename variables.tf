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

variable "project_name" {
  type        = string
  default     = "poc"
  description = "General project name."
}

variable "allowed_sites" {
  type = list(object({
    name = string
    ip   = string
  }))

  default = [
    {
      name = "bestiaZwadowic2137"
      ip   = "janpawel2.pl"
    }
  ]
}

variable "username" {
  type = string
  default = "azureuser"
  description = "Admin username for VMs"
}

variable "key_location" {
  type = string
  default = "./.ssh/vm1"
  description = "Location for ssh key"
}
