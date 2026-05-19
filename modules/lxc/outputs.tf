output "vm_id" {
  description = "Container ID."
  value       = proxmox_virtual_environment_container.this.vm_id
}

output "hostname" {
  description = "Container hostname."
  value       = var.hostname
}

output "ip_address" {
  description = "Static IPv4 (CIDR) or `dhcp`, as passed in."
  value       = var.ip_address
}
