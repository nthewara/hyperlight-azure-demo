variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "location" {
  type    = string
  default = "australiaeast"
}

variable "vm_size" {
  type        = string
  default     = "Standard_D4s_v5"
  description = "Intel v5 D-series — required for nested virtualization / KVM"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key (contents) for the admin user"
}

variable "ssh_source_cidr" {
  type        = string
  description = "Source CIDR allowed to SSH in (lock to your public IP)"
  # No default — must be supplied so we never accidentally open 0.0.0.0/0
}
