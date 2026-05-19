# gha-runner-platform — full-stack worked example

A worked composition for a three-host Proxmox fleet that runs a
self-hosted GitHub Actions runner platform end-to-end. This is the
"start here" example for the recommended architecture.

## Architecture

```
                          GitHub
                            │
                            ▼  (workflow_job.queued webhooks)
                ┌───────────────────────┐
                │   gha-dispatcher LXC  │  (vaterland, VLAN 20)
                │   tiny Go service     │
                └─────────┬─────────────┘
                          │  Nomad API
                          ▼
       ┌──────────────────────────────────────┐
       │  Nomad servers — 3 VMs, one per host │
       │  vaterland / linkstation / n100-b    │
       │  VLAN 20 (services)                  │
       └──────────────────┬───────────────────┘
                          │ schedule
                          ▼
       ┌──────────────────────────────────────┐
       │  Nomad clients — LXCs with nesting    │
       │  linkstation + n100-b                │
       │  VLAN 30 (runners)                   │
       │  └─ ephemeral podman containers per   │
       │     job (--ephemeral --once)         │
       └──────────────────────────────────────┘

  Long-lived service LXCs on VLAN 20:
    token-server   — GitHub App token minting
    registry       — LAN-local OCI registry (NAS-backed)
    gha-dispatcher — webhook → Nomad job submission
```

## VLAN topology

| VLAN | Purpose                                                          |
|------|------------------------------------------------------------------|
| 10   | mgmt (Proxmox UIs, lab admin) — not provisioned by this module   |
| 20   | lab-services (token-server, registry, Nomad servers, dispatcher) |
| 30   | runners (Nomad clients hosting ephemeral podman runner containers) |

Firewall rules (your router/firewall, outside this module's scope):
- `runners → services`: allow specific ports only (token-server 443, registry 5000, NAS 2049)
- `runners → internet`: allow (GitHub, PyPI, npm, package mirrors)
- `runners → mgmt`: **deny**

## No HA, no Proxmox cluster, no Ceph

Each of the three Proxmox hosts is independent. Quorum + spread for
the Nomad layer is what gives the platform its resilience — not
Proxmox HA. If a host dies, jobs running on it fail and reschedule
elsewhere; stateful services (token-server, registry) on that host
are down until it comes back. This is a known, bounded failure mode.

## What this Terraform module covers

- Provisions the **VMs** for Nomad servers
- Provisions the **LXCs** for Nomad clients (with `nesting = true` so
  podman can run inside) and the service stack (token-server,
  registry, dispatcher)
- Wires up VLAN tags and NAS bind-mounts

## What it deliberately does NOT cover

- The **Nomad cluster bootstrap** (servers + clients join, ACLs,
  namespaces) — separate concern, handled by Ansible or a dedicated
  Nomad-terraform-provider module.
- The **LXC template build** (`distrobuilder`) — sibling repo
  `nkg/distrobuilder-proxmox-lxc-images`.
- The **VM template build** (Packer) — sibling repo
  `nkg/packer-proxmox-base-image`. Until that repo exists the module's
  `template.create` mode downloads a stock Ubuntu cloud image as a
  bootstrap convenience.
- The **GitHub App token server image** — sibling repo, runs as a
  podman container inside the token-server LXC.
- The **webhook dispatcher** — sibling repo
  `nkg/gha-nomad-dispatcher`, runs as a podman container inside the
  dispatcher LXC.

## Customising

Adjust IPs, VM IDs, VLAN numbers, and host names in `main.tf` to
match your environment. The shape of the composition (one module
call per Proxmox host with its own provider alias) stays the same.

To target a different number of hosts, add or remove `module
"<host>"` blocks. To skip a host's runner clients, omit the
`nomad-client` entry from that host's `lxcs` map.

## Apply

```bash
tofu init
tofu plan
tofu apply
```

Provider credentials come from `TF_VAR_*_api_token` environment
variables (one per host).
