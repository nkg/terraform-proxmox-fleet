output "template_id" {
  description = "Effective template VM ID used by VMs on this host, or null if none."
  value       = local.effective_template_id
}

output "vms" {
  description = "Map of created VMs keyed by the `vms` map key."
  value = {
    for k, m in module.vm : k => {
      vm_id      = m.vm_id
      ip_address = m.ip_address
      name       = m.name
    }
  }
}

output "lxcs" {
  description = "Map of created LXCs keyed by the `lxcs` map key."
  value = {
    for k, m in module.lxc : k => {
      vm_id      = m.vm_id
      ip_address = m.ip_address
      hostname   = m.hostname
    }
  }
}
