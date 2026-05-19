resource "proxmox_virtual_environment_container" "this" {
  node_name     = var.node_name
  vm_id         = var.vm_id
  tags          = var.tags
  unprivileged  = var.unprivileged
  start_on_boot = var.start_on_boot

  features {
    nesting = var.nesting
    fuse    = var.fuse
    keyctl  = var.keyctl
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  disk {
    datastore_id = var.storage
    size         = var.disk_size
  }

  network_interface {
    name     = "veth0"
    bridge   = var.bridge
    vlan_id  = var.vlan_id
    firewall = false
  }

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.ip_address == "dhcp" ? null : var.gateway
      }
    }

    dynamic "dns" {
      for_each = var.nameserver == null ? [] : [var.nameserver]
      content {
        servers = [dns.value]
      }
    }

    user_account {
      keys = var.ssh_keys
    }
  }

  operating_system {
    template_file_id = var.template_file_id
    # bpg/proxmox requires this even though it's overlapping with the
    # template name — leave it at the broad default; clones pick up the
    # real OS info from the template.
    type = "unmanaged"
  }

  # Mount points cover both volume-backed mounts (Proxmox-managed
  # volumes) and bind mounts (host path → container path). The NAS use
  # case lands on the bind variant: Proxmox host mounts the NFS share
  # externally, then this block binds the host path into the container.
  dynamic "mount_point" {
    for_each = var.mount_points
    content {
      volume    = mount_point.value.volume
      path      = mount_point.value.path
      size      = mount_point.value.size != null ? "${mount_point.value.size}G" : null
      read_only = mount_point.value.read_only
      backup    = mount_point.value.backup
      acl       = mount_point.value.acl
      replicate = mount_point.value.replicate
    }
  }
}
