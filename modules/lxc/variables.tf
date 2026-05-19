variable "node_name" {
  description = "Proxmox node hostname to create the container on."
  type        = string
}

variable "vm_id" {
  description = "Container ID (Proxmox uses the same ID space for VMs and CTs). Must be unique on the target node."
  type        = number
}

variable "hostname" {
  description = "Hostname inside the container; also used as the Proxmox display name."
  type        = string
}

variable "template_file_id" {
  description = <<-EOT
    Proxmox volume reference of the LXC OS template, e.g.
    `local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst`. Build
    custom templates with `distrobuilder` (closest LXC equivalent of
    Packer) or download stock templates with `pveam`.
  EOT
  type        = string
}

variable "unprivileged" {
  description = <<-EOT
    Run as an unprivileged container (uid-mapped, root in container =
    unprivileged uid on host). Default true. Flip to false ONLY for
    containers that genuinely need privileged-on-host capabilities —
    you've thrown away most of LXC's isolation at that point.
  EOT
  type        = bool
  default     = true
}

variable "nesting" {
  description = <<-EOT
    Allow nested containers (`features.nesting = 1` in pct config).
    Required for running podman / docker / nested LXC inside this
    container. Default false. Opt-in because nesting subtly increases
    attack surface.
  EOT
  type        = bool
  default     = false
}

variable "fuse" {
  description = "Enable FUSE inside the container (`features.fuse = 1`). Required for fuse-overlayfs and similar."
  type        = bool
  default     = false
}

variable "keyctl" {
  description = "Enable keyctl inside the container (`features.keyctl = 1`). Required by some container runtimes (esp. unprivileged Docker)."
  type        = bool
  default     = false
}

variable "cores" {
  description = "CPU cores (CFS quota in container terms — not vCPUs)."
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory limit in MB."
  type        = number
  default     = 1024
}

variable "swap" {
  description = "Swap limit in MB."
  type        = number
  default     = 512
}

variable "disk_size" {
  description = "Root filesystem size in GB."
  type        = number
  default     = 8
}

variable "storage" {
  description = "Proxmox storage pool for the root filesystem."
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "Network bridge to attach the container's NIC to."
  type        = string
  default     = "vmbr0"
}

variable "vlan_id" {
  description = "VLAN tag for the NIC. `null` leaves the NIC untagged on the bridge."
  type        = number
  default     = null
}

variable "ip_address" {
  description = "Static IPv4 in CIDR notation. Set to `\"dhcp\"` for DHCP."
  type        = string
}

variable "gateway" {
  description = "Default IPv4 gateway. Required when `ip_address` is static."
  type        = string
  default     = null
}

variable "nameserver" {
  description = "DNS server inside the container. `null` inherits from the host."
  type        = string
  default     = null
}

variable "ssh_keys" {
  description = "SSH public keys for the container's root account."
  type        = list(string)
  default     = []
}

variable "start_on_boot" {
  description = "Auto-start the container when the Proxmox host boots."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Proxmox tags to attach to the container."
  type        = list(string)
  default     = []
}

variable "mount_points" {
  description = <<-EOT
    Bind / volume mounts attached to the container. Use this to bind a
    host path (typically an NFS share already mounted on the Proxmox
    host) into the container — unprivileged LXC can't mount NFS itself,
    so the bind-from-host pattern is the canonical workaround.

    Per entry:
      - `volume`       : Proxmox volume reference (`local-lvm:vm-100-disk-1`)
                         or absolute host path (`/mnt/pve/nas-cache`).
      - `path`         : mount path inside the container.
      - `size`         : size in GB. Required for volume-backed mounts,
                         ignored for bind mounts. Default null.
      - `read_only`    : default false.
      - `backup`       : include in vzdump backups. Default false; set
                         true for genuinely-stateful service data you
                         want backed up.
      - `acl`          : enable POSIX ACLs. Default null (Proxmox
                         default = inherit).
      - `replicate`    : ZFS replication. Default true; flip false for
                         cache mounts where loss is fine.
  EOT
  type = list(object({
    volume    = string
    path      = string
    size      = optional(number)
    read_only = optional(bool, false)
    backup    = optional(bool, false)
    acl       = optional(bool)
    replicate = optional(bool, true)
  }))
  default = []
}
