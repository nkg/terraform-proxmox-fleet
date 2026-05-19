variable "node_name" {
  description = "Proxmox node to create the VM on."
  type        = string
}

variable "vm_id" {
  description = "Proxmox VM ID. Must be unique on the target cluster."
  type        = number
}

variable "name" {
  description = "VM name as it appears in the Proxmox UI."
  type        = string
}

variable "template_id" {
  description = "ID of the Proxmox template VM to clone from."
  type        = number
}

variable "cores" {
  description = "Number of vCPU cores."
  type        = number
  default     = 4
}

variable "memory" {
  description = "Memory in MB."
  type        = number
  default     = 8192
}

variable "disk_size" {
  description = <<-EOT
    Root disk size in GB.

    The 80 GB default exists because lower ceilings tripped `uv sync`
    mid-install for ML projects pulling NVIDIA CUDA libraries (libcufft
    alone is ~600 MB, the full cu13 stack ~3 GB), and the runner host's
    `/var/lib/docker` accumulates ~10–18 GB of layers + build cache
    between weekly prunes. Override down to 30–40 GB for runners with
    light dependencies.
  EOT
  type        = number
  default     = 80
}

variable "storage" {
  description = "Proxmox storage pool for the root disk."
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "Network bridge to attach the runner's NIC to."
  type        = string
  default     = "vmbr0"
}

variable "ip_address" {
  description = "Static IPv4 address in CIDR notation (e.g. `172.16.0.101/24`)."
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
  default     = ["github-runner", "managed"]
}

variable "extra_disks" {
  description = <<-EOT
    Additional disks to attach beyond the root disk. Each entry is a
    map with at minimum `size` (GB) and `storage` (Proxmox pool).
    Disks attach as scsi1, scsi2, ... in declaration order.

    Optional per-disk knobs (with defaults that match the static root
    disk where it makes sense, and the bpg/proxmox provider's
    schema-default elsewhere):
      - `ssd` (false): set true on SSD-backed pools so the guest can
        issue fstrim
      - `iothread` (false)
      - `backup` (true): flip false for scratch/cache disks where the
        cost of nightly backup outweighs the recovery value
      - `replicate` (true): zfs replication, where supported
      - `cache` ("none"): writeback / writethrough / ...
      - `aio` ("io_uring"): requires a modern host kernel — fall back
        to "native" or "threads" on older kernels / NFS-backed pools
      - `discard` ("on"): TRIM passthrough

    Every field is always passed through to the provider, even at its
    default. bpg/proxmox 0.106 errors on `tofu apply` with "Defined
    disk interface not supported" when a dynamic disk block leaves any
    field at its schema default — the apply path serialises empty
    strings for un-set fields and Proxmox rejects them. Pinning every
    attribute sidesteps that bug while still allowing per-disk
    overrides.

    Typical use: mount a slow-tier pool at /var/lib/runner-cache for
    the uv cache + workspace so multi-GB ML extracts don't squeeze the
    fast pool that hosts the rest of the Proxmox VMs.
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
