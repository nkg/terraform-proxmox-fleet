# terraform-proxmox-github-actions-runner

Terraform / OpenTofu module that provisions a single self-hosted GitHub
Actions runner as a Proxmox VM. Compatible with `tofu` ≥ 1.5 and the
`bpg/proxmox` provider in the `~> 0.106` track.

The module **only provisions the VM**. Toolchain install, the GitHub
Actions runner agent, monitoring, and pruning are out of scope — handle
those downstream with Ansible / Komodo / whatever fits.

## Usage

```hcl
module "runner_01" {
  source  = "github.com/<owner>/terraform-proxmox-github-actions-runner?ref=v0.1.0"

  node_name   = "vaterland"
  vm_id       = 200
  name        = "runner-01"
  template_id = 9000
  ip_address  = "172.16.0.101/24"
  gateway     = "172.16.0.1"
  ssh_keys    = ["ssh-ed25519 AAAA... user@host"]

  # Optional: slow-tier scratch disk for uv / build cache.
  extra_disks = [
    { size = 300, storage = "tank", backup = false },
  ]
}
```

See [`examples/basic/`](examples/basic) for a complete worked composition
including provider config.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `node_name` | `string` | — (required) | Proxmox node to create the VM on. |
| `vm_id` | `number` | — (required) | VM ID — must be unique on the target cluster. |
| `name` | `string` | — (required) | VM name as it appears in the Proxmox UI. |
| `template_id` | `number` | — (required) | ID of the Proxmox template VM to clone. |
| `ip_address` | `string` | — (required) | Static IPv4 in CIDR notation (e.g. `172.16.0.101/24`). |
| `gateway` | `string` | — (required) | Default IPv4 gateway. |
| `cores` | `number` | `4` | vCPU cores. |
| `memory` | `number` | `8192` | Memory in MB. |
| `disk_size` | `number` | `80` | Root disk size in GB. See variables.tf for the 80 GB rationale. |
| `storage` | `string` | `"local-lvm"` | Proxmox storage pool for the root disk. |
| `bridge` | `string` | `"vmbr0"` | Network bridge for the NIC. |
| `ssh_keys` | `list(string)` | `[]` | SSH public keys baked into cloud-init for the `deploy` user. |
| `tags` | `list(string)` | `["github-runner", "managed"]` | Proxmox tags on the VM. |
| `extra_disks` | `list(object)` | `[]` | Additional disks (scsi1+). See variables.tf for the per-disk knob set. |

## Outputs

| Name | Description |
|---|---|
| `vm_id` | Proxmox VM ID of the provisioned runner. |
| `ip_address` | Configured static IPv4 address (CIDR, as passed in). |
| `name` | VM name. |

## Design notes

### `lifecycle.ignore_changes = [initialization]` is intentionally absent

A previous in-tree version of this module carried that lifecycle block.
It silently swallowed `ip_address` and `ssh_keys` changes — `tofu plan`
would report "No changes" while Proxmox state and tfvars genuinely
diverged. If a future bpg/proxmox upgrade reintroduces perma-drift on a
specific initialization sub-attribute, narrow the ignore to that
attribute (e.g. `initialization[0].user_account[0].password`) rather
than restoring the broad ignore.

### `aio = "io_uring"` on extra disks

Requires a host kernel with io_uring support — fine on modern Proxmox
(8.x+) but break-glass to `"native"` or `"threads"` on older boxes and
for NFS-backed extra-disk pools (io_uring + NFS is unstable on some
combinations).

### Provider versioning

`bpg/proxmox` is pre-1.0; the `~> 0.106` constraint accepts 0.106.x
patch bumps without picking up 0.107's potentially-breaking changes.
Bump intentionally — see the comment in `versions.tf`.

## Requirements

| Name | Version |
|---|---|
| `tofu` (or `terraform`) | ≥ 1.5 |
| `bpg/proxmox` | `~> 0.106` |

## License

MIT.
