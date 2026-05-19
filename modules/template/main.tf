# Download once per node. Stored under ISO content; the VM disk attach
# below imports it (bpg handles `qm importdisk` semantics via file_id).
resource "proxmox_download_file" "cloud_image" {
  content_type = "iso"
  datastore_id = var.image_datastore
  node_name    = var.node_name
  url          = var.cloud_image_url
  file_name    = var.image_file_name
}

# `template = true` makes Proxmox treat it as a clonable template (no
# boot). Clones receive their own initialization via modules/vm; the
# template only carries baseline OS + cloud-init drive.
resource "proxmox_virtual_environment_vm" "template" {
  node_name = var.node_name
  vm_id     = var.vm_id
  name      = var.name
  template  = true
  tags      = var.tags

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.disk_datastore
    file_id      = proxmox_download_file.cloud_image.id
    interface    = "scsi0"
    ssd          = true
    discard      = "on"
    # Modest base disk; clones resize larger via their own disk_size.
    size        = 8
    file_format = "raw"
  }

  initialization {
    datastore_id = var.disk_datastore
    interface    = "ide2"
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }
}
