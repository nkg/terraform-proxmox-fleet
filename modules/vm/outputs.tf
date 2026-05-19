output "vm_id" {
  description = "Proxmox VM ID."
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "ip_address" {
  description = "Static IPv4 address (CIDR notation, as passed in)."
  value       = var.ip_address
}

output "name" {
  description = "VM name as it appears in the Proxmox UI."
  value       = var.name
}
