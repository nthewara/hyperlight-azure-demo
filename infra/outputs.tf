output "resource_group" {
  value = azurerm_resource_group.rg.name
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.vm.name
}

output "public_ip" {
  value = azurerm_public_ip.pip.ip_address
}

output "admin_username" {
  value = var.admin_username
}

output "ssh_command" {
  value = "ssh ${var.admin_username}@${azurerm_public_ip.pip.ip_address}"
}

output "vm_size" {
  value = var.vm_size
}
