# Every VM gets a cloud-init snippet. It exists for one reason before
# any `extra_runcmd`: the resource below enables the QEMU guest agent
# and the provider then waits for it, but stock cloud images (Ubuntu,
# Debian) do not ship qemu-guest-agent — without installing it here the
# create hangs until the agent timeout and fails.
locals {
  cloud_init_user_data = join("\n", concat(
    [
      "#cloud-config",
      "package_update: true",
      "packages:",
      "  - qemu-guest-agent",
      "users:",
      "  - name: deploy",
      "    sudo: ALL=(ALL) NOPASSWD:ALL",
      "    shell: /bin/bash",
      "    groups: [sudo]",
      "    ssh_authorized_keys:",
    ],
    [for k in var.ssh_keys : "      - ${k}"],
    [
      "runcmd:",
      "  - systemctl enable --now qemu-guest-agent",
    ],
    [for c in var.extra_runcmd : "  - ${c}"],
  ))
}

resource "proxmox_virtual_environment_file" "user_data" {
  content_type = "snippets"
  datastore_id = var.snippets_datastore
  node_name    = var.node_name

  source_raw {
    data      = local.cloud_init_user_data
    file_name = "${var.name}-user-data.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "this" {
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

  # Extra disks attach as scsi1, scsi2, ... in declaration order. Every
  # field is read off `disk.value` with optional() defaults set in
  # variables.tf; defaults must render to concrete values to dodge the
  # bpg/proxmox 0.106 "Defined disk interface not supported" bug.
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
    bridge  = var.bridge
    model   = "virtio"
    vlan_id = var.vlan_id
  }

  # The snippet creates the `deploy` user, so there is no user_account
  # block here — the two would collide in the merged cloud-init. The
  # cloud-init drive itself goes on the VM's own datastore: the
  # provider's default is `local-lvm`, which ZFS-only hosts lack.
  initialization {
    datastore_id = var.storage

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.user_data.id
  }

  agent {
    enabled = true
  }
}
