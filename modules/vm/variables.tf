variable "node_name" {
  description = "Proxmox node hostname to create the VM on (e.g. `pve-01`)."
  type        = string
}

variable "vm_id" {
  description = "Proxmox VM ID. Must be unique on the target node."
  type        = number
}

variable "name" {
  description = "VM name as it appears in the Proxmox UI."
  type        = string
}

variable "template_id" {
  description = "VM ID of the Proxmox template to clone from. Build templates with Packer or via the sibling `modules/template/`."
  type        = number
}

variable "cores" {
  description = "vCPU cores."
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in MB."
  type        = number
  default     = 4096
}

variable "disk_size" {
  description = "Root disk size in GB."
  type        = number
  default     = 32
}

variable "storage" {
  description = "Proxmox storage pool for the root disk."
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "Network bridge to attach the NIC to."
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "VLAN tag for the NIC. `null` (default) leaves the NIC untagged on the bridge."
  type        = number
  default     = null
}

variable "ip_address" {
  description = "Static IPv4 address in CIDR notation (e.g. `192.168.1.101/24`)."
  type        = string
}

variable "gateway" {
  description = "Default IPv4 gateway."
  type        = string
}

variable "ssh_keys" {
  description = "SSH public keys baked into cloud-init for the `deploy` user."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Proxmox tags to attach to the VM."
  type        = list(string)
  default     = []
}

variable "extra_runcmd" {
  description = <<-EOT
    Shell commands appended to cloud-init `runcmd`. Use sparingly — the
    recommended path is a pre-baked template (Packer) so first-boot is
    just network + ssh-key setup. `extra_runcmd` is an escape hatch for
    per-instance config that genuinely can't be baked.
  EOT
  type        = list(string)
  default     = []
}

variable "snippets_datastore" {
  description = <<-EOT
    Proxmox datastore for the uploaded cloud-init snippet. Only used
    when `extra_runcmd` is non-empty. Must have `snippets` in its
    content types — stock Proxmox has it enabled on `local`.
  EOT
  type        = string
  default     = "local"
}

variable "extra_disks" {
  description = <<-EOT
    Additional disks attached as scsi1, scsi2, ... in declaration
    order. Formatting / mounting is the guest's job — this module just
    provisions the block device.

    Every field renders to a concrete value even at default: bpg/proxmox
    0.106 errors on update with "Defined disk interface not supported"
    when a dynamic disk block leaves any field at its schema default
    (the apply path serialises empty strings for unset fields and the
    API rejects them).
  EOT
  type = list(object({
    size      = number
    storage   = string
    ssd       = optional(bool, false)
    iothread  = optional(bool, false)
    backup    = optional(bool, true)
    replicate = optional(bool, true)
    cache     = optional(string, "none")
    aio       = optional(string, "io_uring")
    discard   = optional(string, "on")
  }))
  default = []
}
