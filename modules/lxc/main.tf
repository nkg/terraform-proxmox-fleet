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
    ignore_changes = [features, mount_point]
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
    # Not cosmetic: this is what makes Proxmox write the hostname, the
    # static network config and the SSH keys into the rootfs at create
    # and start (PVE::LXC::Setup). With `unmanaged` it writes nothing,
    # and the container comes up with the template's placeholder
    # hostname, an unconfigured NIC and no authorized_keys — the
    # initialization block above is silently a no-op.
    type = var.os_type
  }

  # Only volume-backed mounts (Proxmox-managed volumes) go through the
  # API. Bind mounts (host path → container path) are, like the feature
  # flags, root@pam-only on the API ("mount point type bind is only
  # allowed for root@pam") and are applied with `pct set` below. The
  # provider then sees mount points in the config it did not declare, so
  # mount_point is in ignore_changes above — a change to a volume mount
  # after creation needs a taint.
  dynamic "mount_point" {
    for_each = local.volume_mounts
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

# fuse / keyctl and bind mounts need root@pam on the API, so they are
# applied on the host with `pct` as root via sudo. The full feature set
# (nesting included) is written so the config is exactly what was asked
# for. Bind mounts take mp indices after the API-managed volume mounts,
# which bpg numbers mp0.. in list order. The container is rebooted only
# when its config actually changed — features take effect at start, and
# a bind mount added to a running container is not visible inside until
# then either.
locals {
  volume_mounts = [for m in var.mount_points : m if !startswith(m.volume, "/")]
  bind_mounts   = [for m in var.mount_points : m if startswith(m.volume, "/")]

  features = join(",", compact([
    var.nesting ? "nesting=1" : "",
    var.fuse ? "fuse=1" : "",
    var.keyctl ? "keyctl=1" : "",
  ]))

  bind_mount_args = [
    for i, m in local.bind_mounts :
    format("--mp%d '%s'", length(local.volume_mounts) + i, join(",", compact([
      m.volume,
      "mp=${m.path}",
      m.read_only ? "ro=1" : "",
      m.backup ? "backup=1" : "backup=0",
      m.acl == null ? "" : (m.acl ? "acl=1" : "acl=0"),
      m.replicate ? "" : "replicate=0",
    ])))
  ]

  host_side_needed = var.fuse || var.keyctl || length(local.bind_mounts) > 0
}

# v0.1.1 applied the feature flags alone under this name.
moved {
  from = terraform_data.features
  to   = terraform_data.host_config
}

resource "terraform_data" "host_config" {
  count = local.host_side_needed ? 1 : 0

  triggers_replace = [
    proxmox_virtual_environment_container.this.id,
    local.features,
    join(" ", local.bind_mount_args),
  ]

  lifecycle {
    precondition {
      condition     = var.host_ssh != null
      error_message = "LXC ${var.hostname}: fuse/keyctl and bind mounts are set with `pct set` over SSH, which needs `host_ssh` ({ host, user, private_key }) — Proxmox only allows those for root@pam on the API."
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
      "before=$(sudo -n pct config ${var.vm_id} | grep -E '^(features|mp[0-9]+):' || true)",
      "sudo -n pct set ${var.vm_id} --features '${local.features}' ${join(" ", local.bind_mount_args)}",
      "after=$(sudo -n pct config ${var.vm_id} | grep -E '^(features|mp[0-9]+):' || true)",
      "if [ \"$before\" != \"$after\" ] && sudo -n pct status ${var.vm_id} | grep -q running; then sudo -n pct reboot ${var.vm_id}; fi",
    ]
  }
}
