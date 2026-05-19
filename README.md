# terraform-proxmox-fleet

Terraform / OpenTofu module that provisions a fleet of VMs and LXC
containers on a Proxmox host. Single-host scope per module
invocation — to deploy across multiple hosts, the caller declares one
provider alias per host and invokes the module once per host (no
Proxmox cluster required).

Originally extracted to back a self-hosted GitHub Actions runner
platform, but the module itself is generic Proxmox fleet
provisioning. The runner-specific example (`examples/gha-runner-platform/`)
shows the recommended end-to-end shape: Nomad servers as VMs, Nomad
clients as nesting-enabled LXCs, long-lived services (token-server,
registry, dispatcher) as small unprivileged LXCs.

> Note: the repo is named
> `terraform-proxmox-github-actions-runner` for historical reasons.
> The module is now generic — rename to `terraform-proxmox-fleet` is
> planned.

Tested with `tofu` ≥ 1.5 and `bpg/proxmox ~> 0.106`.

## Layout

```
.                       Top-level orchestration (module entrypoint)
├── modules/
│   ├── vm/             Proxmox VM clone with optional cloud-init runcmd
│   ├── lxc/            Proxmox LXC container (unprivileged by default)
│   └── template/       Optional cloud-image template VM (Packer is the long-term home)
└── examples/
    ├── single-vm/      One VM, existing template
    ├── single-lxc/     One unprivileged LXC
    └── gha-runner-platform/   Full three-host fleet for GHA runner platform
```

Sub-modules are independently consumable — `source = "./modules/lxc"`
works fine if the top-level orchestration doesn't fit.

## Quick start — single host

```hcl
module "fleet" {
  source = "github.com/nkg/terraform-proxmox-github-actions-runner?ref=v1.0.0"

  node_name = "vaterland"
  gateway   = "172.16.0.1"
  ssh_keys  = ["ssh-ed25519 AAAA... user@host"]

  template = { id = 9000 }  # or { create = { vm_id = 9000 } }

  vms = {
    "nomad-server" = {
      name       = "nomad-server-01"
      vm_id      = 101
      ip_address = "172.16.0.121/24"
      vlan_id    = 20
      cores      = 2
      memory     = 2048
    }
  }

  lxcs = {
    "registry" = {
      hostname         = "registry"
      vm_id            = 201
      ip_address       = "172.16.0.132/24"
      vlan_id          = 20
      template_file_id = "local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst"
      nesting          = true   # to run podman / docker inside
      keyctl           = true
      fuse             = true
      mount_points = [
        { volume = "/mnt/pve/nas-cache", path = "/var/lib/registry", backup = false }
      ]
    }
  }
}
```

For the **multi-host** pattern, see [`examples/gha-runner-platform/`](examples/gha-runner-platform/) — one provider alias and one module call per Proxmox host.

## Inputs (top-level)

| Name | Type | Default | Description |
|---|---|---|---|
| `node_name` | `string` | — (required) | Proxmox node this invocation targets. |
| `gateway` | `string` | — (required) | Default IPv4 gateway. |
| `bridge` | `string` | `"vmbr0"` | Default network bridge. |
| `default_vlan_id` | `number` | `null` | Default VLAN tag for NICs (null = untagged). Per-entry override. |
| `vm_storage` | `string` | `"local-lvm"` | Default Proxmox pool for VM root disks. |
| `lxc_storage` | `string` | `"local-lvm"` | Default Proxmox pool for LXC root filesystems. |
| `ssh_keys` | `list(string)` | `[]` | Default SSH keys for `deploy` user (VMs) / root (LXCs). |
| `snippets_datastore` | `string` | `"local"` | Datastore for cloud-init snippet uploads (used by `extra_runcmd`). |
| `template` | `object` | `null` | Either `{id=N}` (existing template) or `{create={...}}` (module builds one). Null = no VMs on this host. |
| `vms` | `map(object)` | `{}` | VMs to create. Per entry: `name`, `vm_id`, `ip_address` required. |
| `lxcs` | `map(object)` | `{}` | LXCs to create. Per entry: `hostname`, `vm_id`, `ip_address`, `template_file_id` required. |

See [`variables.tf`](variables.tf) for the full per-VM / per-LXC field
sets (`cores`, `memory`, `nesting`, `mount_points`, `extra_disks`,
etc.).

## Outputs

| Name | Description |
|---|---|
| `template_id` | Effective template VM ID, or null if no VMs created. |
| `vms` | Map of created VMs (`vm_id`, `ip_address`, `name`). |
| `lxcs` | Map of created LXCs (`vm_id`, `ip_address`, `hostname`). |

## Design notes

### Single-host scope per invocation

The module configures one provider and targets one Proxmox node.
Multi-host fleets are composed at the **caller** level — one provider
alias per host, one module call per host. This keeps the module out
of cluster-state and multi-host scheduling concerns (those belong to
Nomad / Komodo / whatever the runtime scheduler is).

### Pre-baked templates over cloud-init runcmd

`var.template = { create = {...} }` and per-VM `extra_runcmd` are
escape hatches for first-time setup. The recommended long-term path
is **Packer for VMs** and **distrobuilder for LXCs** — bake your
toolchain into the image so first boot is just network + ssh-key
setup. Sibling repos under `nkg/` will host these template builders.

### Unprivileged LXC by default

`lxcs.<key>.unprivileged` defaults to `true`. Containers that need
nested container runtimes (podman, docker) must opt into
`nesting = true` — and almost always also `keyctl = true` and
`fuse = true`. Privileged LXC is supported but is essentially
"root in container ≈ root on host"; only use it when you have a
specific reason and accept the loss of isolation.

### NAS mounts use the host-bind pattern

Unprivileged LXC can't mount NFS or SMB directly (the mount syscall
needs `CAP_SYS_ADMIN` in the initial user namespace). The canonical
workaround is for the **Proxmox host** to mount the share, and the
LXC to bind-mount the host path. Declare these via `mount_points` —
`volume` is an absolute host path (e.g. `/mnt/pve/nas-cache`),
`path` is where it lands inside the container. UID mapping is the
gotcha: a file written as uid 0 inside the container lands as uid
100000 on the host; match the NAS share's anon uid / set
`lxc.idmap` accordingly.

### `lifecycle.ignore_changes = [initialization]` intentionally absent

A previous iteration of this module carried that lifecycle block —
it silently swallowed `ip_address` and `ssh_keys` changes and made
`tofu plan` report "No changes" while Proxmox state and tfvars
diverged. If a future bpg/proxmox upgrade reintroduces perma-drift
on a specific initialization sub-attribute, narrow the ignore to
that attribute (e.g. `initialization[0].user_account[0].password`)
rather than restoring the broad ignore.

### Provider versioning

`bpg/proxmox` is pre-1.0; `~> 0.106` accepts 0.106.x patch bumps
without picking up 0.107's potentially-breaking changes. Bump
intentionally.

## Requirements

| Name | Version |
|---|---|
| `tofu` (or `terraform`) | ≥ 1.5 |
| `bpg/proxmox` | `~> 0.106` |
| Proxmox VE | 8.x+ recommended |
| Snippets-enabled datastore | Required only when VMs have `extra_runcmd` set |

## License

MIT.
