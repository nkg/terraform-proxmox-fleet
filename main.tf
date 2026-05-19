resource "proxmox_virtual_environment_vm" "runner" {
  node_name = var.node_name
  vm_id     = var.vm_id
  name      = var.name
  tags      = var.tags

  clone {
    vm_id = var.template_id
    full  = true
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.storage
    size         = var.disk_size
    interface    = "scsi0"
    ssd          = true
    discard      = "on"
  }

  # Extra disks attach as scsi1, scsi2, ... in declaration order.
  # Format/mount is handled by the consumer (typically ansible) once the
  # VM is up — this module only provisions the block device.
  #
  # Every field is read off `disk.value` (with optional() defaults in
  # variables.tf). The defaults must always render to a concrete value:
  # bpg/proxmox 0.106 errors on update with "Interface was , but only
  # [ide sata scsi virtio] are supported" if the dynamic block leaves
  # any disk field at its schema default — the apply path serialises
  # empty strings for un-set fields and the API rejects them.
  dynamic "disk" {
    for_each = var.extra_disks
    content {
      datastore_id = disk.value.storage
      size         = disk.value.size
      interface    = "scsi${disk.key + 1}"
      ssd          = disk.value.ssd
      iothread     = disk.value.iothread
      backup       = disk.value.backup
      replicate    = disk.value.replicate
      cache        = disk.value.cache
      aio          = disk.value.aio
      discard      = disk.value.discard
    }
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    user_account {
      username = "deploy"
      keys     = var.ssh_keys
    }
  }

  agent {
    enabled = true
  }

  # Intentionally no `lifecycle { ignore_changes = [initialization] }`.
  # An earlier in-tree version of this module shipped with that ignore
  # since its first commit, with no explanation — likely a defensive
  # copy-paste rather than a fix for observed drift. The cost was real:
  # `ip_address` / `ssh_keys` updates were silently swallowed and
  # `tofu plan` reported "No changes" while Proxmox state and tfvars
  # diverged. If a future bpg/proxmox upgrade reintroduces perma-drift
  # on a specific initialization sub-attribute, narrow the ignore to
  # that attribute (e.g. `initialization[0].user_account[0].password`)
  # rather than restoring the broad ignore.
}
