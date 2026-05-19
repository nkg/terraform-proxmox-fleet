terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.106"
    }
  }
}

# ─── One provider alias per Proxmox host ─────────────────────────────
#
# No Proxmox cluster — three independent hosts, each with its own
# endpoint and credentials. The module is invoked once per host with
# the matching provider alias.

provider "proxmox" {
  alias    = "vaterland"
  endpoint = var.vaterland_endpoint
  insecure = var.proxmox_insecure

  api_token = var.vaterland_api_token

  ssh {
    agent = true
  }
}

provider "proxmox" {
  alias    = "linkstation"
  endpoint = var.linkstation_endpoint
  insecure = var.proxmox_insecure

  api_token = var.linkstation_api_token

  ssh {
    agent = true
  }
}

provider "proxmox" {
  alias    = "n100_b"
  endpoint = var.n100_b_endpoint
  insecure = var.proxmox_insecure

  api_token = var.n100_b_api_token

  ssh {
    agent = true
  }
}

# ─── Shared inputs ───────────────────────────────────────────────────

locals {
  # VLAN topology:
  # 10 = mgmt (Proxmox UIs, lab admin) — not used by this module
  # 20 = lab-services (token-server, registry, Nomad servers, monitoring, NAS)
  # 30 = runners (Nomad clients hosting podman runner containers)
  vlan_services = 20
  vlan_runners  = 30

  # All three Proxmox hosts share LAN, gateway, and the NAS export
  # from vaterland (172.16.0.20:/tank/runners/buildkit-cache).
  gateway = "172.16.0.1"

  # LXC template (built once with distrobuilder, lives on each host's
  # `local` storage, or shared via NFS template store).
  lxc_template = "local:vztmpl/runner-base-1.0.tar.zst"
}

# ─── vaterland — Nomad server + token-server + registry ──────────────

module "vaterland" {
  source = "../.."
  providers = {
    proxmox = proxmox.vaterland
  }

  node_name = "vaterland"
  gateway   = local.gateway
  ssh_keys  = var.ssh_keys

  # Nomad server VMs use the pre-built Packer template (recommended
  # over the cloud-init bootstrap path); for the example we let the
  # module create a stock cloud-image template once.
  template = {
    create = {
      vm_id = 9000
    }
  }

  vms = {
    "nomad-server" = {
      name       = "nomad-server-vaterland"
      vm_id      = 1101
      ip_address = "172.16.0.121/24"
      vlan_id    = local.vlan_services
      cores      = 2
      memory     = 2048
      tags       = ["nomad-server"]
    }
  }

  lxcs = {
    "token-server" = {
      hostname         = "token-server"
      vm_id            = 1201
      ip_address       = "172.16.0.131/24"
      vlan_id          = local.vlan_services
      template_file_id = local.lxc_template
      cores            = 1
      memory           = 256
      nesting          = true # runs the token-server as a podman container
      keyctl           = true
      fuse             = true
      tags             = ["token-server", "service"]
    }

    "registry" = {
      hostname         = "registry"
      vm_id            = 1202
      ip_address       = "172.16.0.132/24"
      vlan_id          = local.vlan_services
      template_file_id = local.lxc_template
      cores            = 1
      memory           = 512
      nesting          = true
      keyctl           = true
      fuse             = true
      tags             = ["registry", "service"]

      # Registry storage on the vaterland NFS export (already mounted
      # on the Proxmox host at /mnt/pve/runner-nfs). The bind path is
      # invisible to non-host code; only the registry process inside
      # the LXC sees /var/lib/registry.
      mount_points = [
        {
          volume = "/mnt/pve/runner-nfs/registry"
          path   = "/var/lib/registry"
          backup = false # data lives on NAS, not on the LXC root disk
        }
      ]
    }

    "dispatcher" = {
      hostname         = "gha-dispatcher"
      vm_id            = 1203
      ip_address       = "172.16.0.133/24"
      vlan_id          = local.vlan_services
      template_file_id = local.lxc_template
      cores            = 1
      memory           = 256
      nesting          = false # tiny Go service, no nested containers
      tags             = ["dispatcher", "service"]
    }
  }
}

# ─── linkstation-n2 — Nomad server + Nomad client ────────────────────

module "linkstation" {
  source = "../.."
  providers = {
    proxmox = proxmox.linkstation
  }

  node_name   = "linkstation-n2"
  gateway     = local.gateway
  ssh_keys    = var.ssh_keys
  vm_storage  = "local-zfs" # 4TB SSD data pool
  lxc_storage = "local-zfs"

  template = {
    create = {
      vm_id          = 9000
      disk_datastore = "local-zfs"
    }
  }

  vms = {
    "nomad-server" = {
      name       = "nomad-server-linkstation"
      vm_id      = 2101
      ip_address = "172.16.0.122/24"
      vlan_id    = local.vlan_services
      cores      = 2
      memory     = 2048
      tags       = ["nomad-server"]
    }
  }

  lxcs = {
    "nomad-client" = {
      hostname         = "nomad-client-linkstation"
      vm_id            = 2201
      ip_address       = "172.16.0.151/24"
      vlan_id          = local.vlan_runners
      template_file_id = local.lxc_template
      cores            = 6 # leave 2 for nomad-server VM + host
      memory           = 10240
      disk_size        = 40
      nesting          = true # runs podman for ephemeral runner workloads
      keyctl           = true
      fuse             = true
      tags             = ["nomad-client", "runner"]

      # Shared build cache mounted from vaterland NFS so all runner
      # hosts hit the same BuildKit / dependency cache.
      mount_points = [
        {
          volume = "/mnt/pve/runner-nfs/buildkit-cache"
          path   = "/var/cache/buildkit"
          backup = false
        }
      ]
    }
  }
}

# ─── n100_b — Nomad server + Nomad client ────────────────────────────

module "n100_b" {
  source = "../.."
  providers = {
    proxmox = proxmox.n100_b
  }

  node_name = "n100-b"
  gateway   = local.gateway
  ssh_keys  = var.ssh_keys

  template = {
    create = {
      vm_id = 9000
    }
  }

  vms = {
    "nomad-server" = {
      name       = "nomad-server-n100-b"
      vm_id      = 3101
      ip_address = "172.16.0.123/24"
      vlan_id    = local.vlan_services
      cores      = 2
      memory     = 2048
      tags       = ["nomad-server"]
    }
  }

  lxcs = {
    "nomad-client" = {
      hostname         = "nomad-client-n100-b"
      vm_id            = 3201
      ip_address       = "172.16.0.152/24"
      vlan_id          = local.vlan_runners
      template_file_id = local.lxc_template
      cores            = 6
      memory           = 10240
      disk_size        = 40
      nesting          = true
      keyctl           = true
      fuse             = true
      tags             = ["nomad-client", "runner"]

      mount_points = [
        {
          volume = "/mnt/pve/runner-nfs/buildkit-cache"
          path   = "/var/cache/buildkit"
          backup = false
        }
      ]
    }
  }
}

# ─── Aggregated outputs ──────────────────────────────────────────────

output "vaterland_vms" { value = module.vaterland.vms }
output "vaterland_lxcs" { value = module.vaterland.lxcs }
output "linkstation_vms" { value = module.linkstation.vms }
output "linkstation_lxcs" { value = module.linkstation.lxcs }
output "n100_b_vms" { value = module.n100_b.vms }
output "n100_b_lxcs" { value = module.n100_b.lxcs }
