resource "proxmox_virtual_environment_container" "this" {
  node_name     = var.node_name
  vm_id         = var.vm_id
  tags          = var.tags
  unprivileged  = var.unprivileged
  start_on_boot = var.start_on_boot

  # Only `nesting` goes through the API. Proxmox refuses every other
  # feature flag for anyone but root@pam ("changing feature flags
  # (except nesting) is only allowed for root@pam"), and this module
  # is meant to run on a scoped token. `fuse` / `keyctl` are set by
  # `pct set` over SSH below; the provider must then not try to undo
  # them, hence ignore_changes.
  features {
    nesting = var.nesting
  }

  lifecycle {
    ignore_changes = [features]
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

# fuse / keyctl need root@pam on the API, so they are applied on the
# host with `pct set` as root via sudo. The full flag set (nesting
# included) is written so the config is exactly what was asked for,
# and the container is rebooted only when the line actually changed —
# features take effect at container start.
locals {
  features = join(",", compact([
    var.nesting ? "nesting=1" : "",
    var.fuse ? "fuse=1" : "",
    var.keyctl ? "keyctl=1" : "",
  ]))
}

resource "terraform_data" "features" {
  count = (var.fuse || var.keyctl) ? 1 : 0

  triggers_replace = [proxmox_virtual_environment_container.this.id, local.features]

  lifecycle {
    precondition {
      condition     = var.host_ssh != null
      error_message = "LXC ${var.hostname}: fuse/keyctl are set with `pct set` over SSH, which needs `host_ssh` ({ host, user, private_key }) — Proxmox only allows those flags for root@pam on the API."
    }
  }

  connection {
    type        = "ssh"
    host        = var.host_ssh.host
    user        = var.host_ssh.user
    private_key = var.host_ssh.private_key
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "before=$(sudo -n pct config ${var.vm_id} | sed -n 's/^features: //p')",
      "sudo -n pct set ${var.vm_id} --features '${local.features}'",
      "after=$(sudo -n pct config ${var.vm_id} | sed -n 's/^features: //p')",
      "if [ \"$before\" != \"$after\" ] && sudo -n pct status ${var.vm_id} | grep -q running; then sudo -n pct reboot ${var.vm_id}; fi",
    ]
  }
}
