# ─── Single-host fleet ────────────────────────────────────────────────
#
# This module provisions VMs + LXCs on ONE Proxmox host per invocation.
# To deploy across multiple hosts, the caller declares one provider
# alias per host and invokes this module once per host:
#
#   provider "proxmox" { alias = "pve-01"   endpoint = "..." }
#   provider "proxmox" { alias = "pve_02" endpoint = "..." }
#
#   module "pve_01"   { source = "..." providers = { proxmox = proxmox.pve_01   } node_name = "pve-01"      vms = {...} }
#   module "pve_02" { source = "..." providers = { proxmox = proxmox.pve_02 } node_name = "pve-02" vms = {...} }
#
# This shape keeps the module out of the multi-host scheduling business
# — that's the caller's concern (and, at runtime, Nomad's).

variable "node_name" {
  description = "Proxmox node hostname this module invocation targets."
  type        = string
}

# ─── Shared defaults (overridable per-entry) ─────────────────────────

variable "gateway" {
  description = "Default IPv4 gateway. Per-entry `gateway` overrides."
  type        = string
}

variable "bridge" {
  description = "Default network bridge. Per-entry `bridge` overrides."
  type        = string
  default     = "vmbr0"
}

variable "default_vlan_id" {
  description = "Default VLAN tag for VM/LXC NICs. `null` (default) leaves NICs untagged. Per-entry `vlan_id` overrides."
  type        = number
  default     = null
}

variable "vm_storage" {
  description = "Default Proxmox storage pool for VM root disks. Per-entry `storage` overrides."
  type        = string
  default     = "local-lvm"
}

variable "lxc_storage" {
  description = "Default Proxmox storage pool for LXC root filesystems. Per-entry `storage` overrides."
  type        = string
  default     = "local-lvm"
}

variable "ssh_keys" {
  description = "Default SSH public keys for the `deploy` user (VMs) / root (LXCs). Per-entry `ssh_keys` overrides."
  type        = list(string)
  default     = []
}

variable "snippets_datastore" {
  description = "Datastore for cloud-init snippet uploads (VM `extra_runcmd`). Must allow `snippets` content type."
  type        = string
  default     = "local"
}

# ─── Template: bring your own, or have the module build one ──────────

variable "template" {
  description = <<-EOT
    Template for VM clones to use. Set EXACTLY ONE of:

    - `id`     : VM ID of an existing template (Packer-built or earlier
                 run of this module).
    - `create` : let `modules/template` download an Ubuntu cloud image
                 and create a template VM. The recommended long-term
                 path is a Packer-built template — `create` is a
                 convenience for first-time setup.

    Set to `null` if this invocation creates no VMs (LXC-only host).
  EOT

  type = object({
    id = optional(number)
    create = optional(object({
      vm_id           = number
      name            = optional(string, "ubuntu-noble-cloud")
      cloud_image_url = optional(string, "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img")
      image_file_name = optional(string, "noble-server-cloudimg-amd64.img")
      image_datastore = optional(string, "local")
      disk_datastore  = optional(string)
    }))
  })

  default = null

  validation {
    condition = (
      var.template == null
      || (try(var.template.id, null) != null) != (try(var.template.create, null) != null)
    )
    error_message = "When set, `template` must have exactly one of `id` or `create`."
  }
}

# ─── VMs ─────────────────────────────────────────────────────────────

variable "vms" {
  description = <<-EOT
    Map of VMs to create on this host. Map key is a stable logical name
    used in resource addressing (e.g. `module.fleet.module.vm["nomad-server"]`).

    Required per entry: `name`, `vm_id`, `ip_address`. Everything else
    falls back to top-level defaults or sensible per-role defaults.
  EOT

  type = map(object({
    name       = string
    vm_id      = number
    ip_address = string

    cores     = optional(number, 2)
    memory    = optional(number, 4096)
    disk_size = optional(number, 32)
    storage   = optional(string)

    bridge   = optional(string)
    vlan_id  = optional(number)
    gateway  = optional(string)
    ssh_keys = optional(list(string))

    tags         = optional(list(string), [])
    extra_runcmd = optional(list(string), [])

    extra_disks = optional(list(object({
      size      = number
      storage   = string
      ssd       = optional(bool, false)
      iothread  = optional(bool, false)
      backup    = optional(bool, true)
      replicate = optional(bool, true)
      cache     = optional(string, "none")
      aio       = optional(string, "io_uring")
      discard   = optional(string, "on")
    })), [])
  }))

  default = {}
}

# ─── LXCs ────────────────────────────────────────────────────────────

variable "lxcs" {
  description = <<-EOT
    Map of LXC containers to create on this host. Map key is a stable
    logical name used in resource addressing.

    Required per entry: `hostname`, `vm_id`, `ip_address`, `template_file_id`.
    LXC templates are referenced by Proxmox volume path (e.g.
    `local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst`), not by ID.

    Defaults: unprivileged, no nesting, no FUSE, no keyctl. Containers
    that need to run podman / docker / nested LXC must set
    `nesting = true` (and often `keyctl = true`, `fuse = true`).

    NAS bind-mount pattern: declare a `mount_point` with `volume` set
    to the host path (`/mnt/pve/nas-cache`) and `path` set to the
    container path. The Proxmox host handles the actual NFS/SMB mount
    externally — unprivileged LXC can't mount those itself.
  EOT

  type = map(object({
    hostname         = string
    vm_id            = number
    ip_address       = string
    template_file_id = string

    cores     = optional(number, 2)
    memory    = optional(number, 1024)
    swap      = optional(number, 512)
    disk_size = optional(number, 8)
    storage   = optional(string)

    bridge     = optional(string)
    vlan_id    = optional(number)
    gateway    = optional(string)
    nameserver = optional(string)
    ssh_keys   = optional(list(string))

    unprivileged  = optional(bool, true)
    nesting       = optional(bool, false)
    fuse          = optional(bool, false)
    keyctl        = optional(bool, false)
    start_on_boot = optional(bool, true)

    tags = optional(list(string), [])

    mount_points = optional(list(object({
      volume    = string
      path      = string
      size      = optional(number)
      read_only = optional(bool, false)
      backup    = optional(bool, false)
      acl       = optional(bool)
      replicate = optional(bool, true)
    })), [])
  }))

  default = {}
}
