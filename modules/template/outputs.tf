output "template_id" {
  description = "VM ID of the created template, suitable for use as `template_id` in modules/vm."
  value       = proxmox_virtual_environment_vm.template.vm_id
}

output "name" {
  description = "Template name as it appears in the Proxmox UI."
  value       = var.name
}
