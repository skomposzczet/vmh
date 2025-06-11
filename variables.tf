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


