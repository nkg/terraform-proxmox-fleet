variable "node_name" {
  description = "Proxmox node to download the image to and create the template on."
  type        = string
}

variable "vm_id" {
  description = "VM ID for the template. Must be unique on the target node."
  type        = number
}

variable "name" {
  description = "Template name as it appears in the Proxmox UI."
  type        = string
  default     = "ubuntu-noble-cloud"
}

variable "cloud_image_url" {
  description = <<-EOT
    HTTP(S) URL of the cloud image to download. Default is Ubuntu 24.04
    (noble) server cloud image for amd64. Override for a different
    distro or release — bpg downloads it once to the target datastore
    and reuses on subsequent runs.

    Recommended longer-term path: replace this module with Packer for
    VM templates (lets you bake podman, runner agent, toolchain into
    the image instead of installing per-clone via cloud-init).
  EOT
  type        = string
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "image_file_name" {
  description = "Filename for the downloaded image. Default matches the Ubuntu noble URL."
  type        = string
  default     = "noble-server-cloudimg-amd64.img"
}

variable "image_datastore" {
  description = "Datastore for the downloaded cloud image (`iso` content type)."
  type        = string
  default     = "local"
}

variable "disk_datastore" {
  description = "Datastore for the template VM's root disk."
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "Network bridge for the template VM. Clones inherit this unless overridden."
  type        = string
  default     = "vmbr0"
}

variable "cores" {
  description = "vCPU cores for the template VM. Cosmetic — clones override."
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in MB for the template VM. Cosmetic — clones override."
  type        = number
  default     = 2048
}

variable "tags" {
  description = "Proxmox tags to attach to the template."
  type        = list(string)
  default     = ["template", "cloud-init"]
}
