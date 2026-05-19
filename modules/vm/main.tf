locals {
  cloud_init_user_data = length(var.extra_runcmd) > 0 ? join("\n", concat(
    [
      "#cloud-config",
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
    ],
    [for c in var.extra_runcmd : "  - ${c}"],
  )) : null
}

resource "proxmox_virtual_environment_file" "user_data" {
  count = length(var.extra_runcmd) > 0 ? 1 : 0

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

  # When extra_runcmd is set the snippet provides user creation; the
  # provider's user_account block is dropped to avoid colliding with
  # the snippet's `users:` section in the merged cloud-init.
  initialization {
    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    user_data_file_id = length(var.extra_runcmd) > 0 ? proxmox_virtual_environment_file.user_data[0].id : null

    dynamic "user_account" {
      for_each = length(var.extra_runcmd) > 0 ? [] : [1]
      content {
        username = "deploy"
        keys     = var.ssh_keys
      }
    }
  }

  agent {
    enabled = true
  }
}
