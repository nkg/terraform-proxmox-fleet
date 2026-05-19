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
  alias    = "pve_01"
  endpoint = var.pve_01_endpoint
  insecure = var.proxmox_insecure

  api_token = var.pve_01_api_token

  ssh {
    agent = true
  }
}

provider "proxmox" {
  alias    = "pve_02"
  endpoint = var.pve_02_endpoint
  insecure = var.proxmox_insecure

  api_token = var.pve_02_api_token

  ssh {
    agent = true
  }
}

provider "proxmox" {
  alias    = "pve_03"
  endpoint = var.pve_03_endpoint
  insecure = var.proxmox_insecure

  api_token = var.pve_03_api_token

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
  # from pve-01 (192.168.1.10:/srv/nfs/buildkit-cache).
  gateway = "192.168.1.1"

  # LXC template (built once with distrobuilder, lives on each host's
  # `local` storage, or shared via NFS template store).
  lxc_template = "local:vztmpl/runner-base-1.0.tar.zst"
}

# ─── pve-01 — Nomad server + token-server + registry ──────────────

module "pve_01" {
  source = "../.."
  providers = {
    proxmox = proxmox.pve_01
  }

  node_name = "pve-01"
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
      name       = "nomad-server-pve-01"
      vm_id      = 1101
      ip_address = "192.168.1.121/24"
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
      ip_address       = "192.168.1.131/24"
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
      ip_address       = "192.168.1.132/24"
      vlan_id          = local.vlan_services
      template_file_id = local.lxc_template
      cores            = 1
      memory           = 512
      nesting          = true
      keyctl           = true
      fuse             = true
      tags             = ["registry", "service"]

      # Registry storage on the pve-01 NFS export (already mounted
      # on the Proxmox host at /mnt/pve/runner-nfs). The bind path is
      # invisible to non-host code; only the registry process inside
      # the LXC sees /var/lib/registry.
      mount_points = [
        {
          volume = "/mnt/pve/nfs-cache/registry"
          path   = "/var/lib/registry"
          backup = false # data lives on NAS, not on the LXC root disk
        }
      ]
    }

    "dispatcher" = {
      hostname         = "gha-dispatcher"
      vm_id            = 1203
      ip_address       = "192.168.1.133/24"
      vlan_id          = local.vlan_services
      template_file_id = local.lxc_template
      cores            = 1
      memory           = 256
      nesting          = false # tiny Go service, no nested containers
      tags             = ["dispatcher", "service"]
    }
  }
}

# ─── pve-02 — Nomad server + Nomad client ────────────────────

module "pve_02" {
  source = "../.."
  providers = {
    proxmox = proxmox.pve_02
  }

  node_name   = "pve-02"
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
      name       = "nomad-server-pve-02"
      vm_id      = 2101
      ip_address = "192.168.1.122/24"
      vlan_id    = local.vlan_services
      cores      = 2
      memory     = 2048
      tags       = ["nomad-server"]
    }
  }

  lxcs = {
    "nomad-client" = {
      hostname         = "nomad-client-pve-02"
      vm_id            = 2201
      ip_address       = "192.168.1.151/24"
      vlan_id          = local.vlan_runners
      template_file_id = local.lxc_template
      cores            = 6 # leave 2 for nomad-server VM + host
      memory           = 10240
      disk_size        = 40
      nesting          = true # runs podman for ephemeral runner workloads
      keyctl           = true
      fuse             = true
      tags             = ["nomad-client", "runner"]

      # Shared build cache mounted from pve-01 NFS so all runner
      # hosts hit the same BuildKit / dependency cache.
      mount_points = [
        {
          volume = "/mnt/pve/nfs-cache/buildkit-cache"
          path   = "/var/cache/buildkit"
          backup = false
        }
      ]
    }
  }
}

# ─── pve-03 — Nomad server + Nomad client ────────────────────────────

module "pve_03" {
  source = "../.."
  providers = {
    proxmox = proxmox.pve_03
  }

  node_name = "pve-03"
  gateway   = local.gateway
  ssh_keys  = var.ssh_keys

  template = {
    create = {
      vm_id = 9000
    }
  }

  vms = {
    "nomad-server" = {
      name       = "nomad-server-pve-03"
      vm_id      = 3101
      ip_address = "192.168.1.123/24"
      vlan_id    = local.vlan_services
      cores      = 2
      memory     = 2048
      tags       = ["nomad-server"]
    }
  }

  lxcs = {
    "nomad-client" = {
      hostname         = "nomad-client-pve-03"
      vm_id            = 3201
      ip_address       = "192.168.1.152/24"
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
          volume = "/mnt/pve/nfs-cache/buildkit-cache"
          path   = "/var/cache/buildkit"
          backup = false
        }
      ]
    }
  }
}

# ─── Aggregated outputs ──────────────────────────────────────────────

output "pve_01_vms" { value = module.pve_01.vms }
output "pve_01_lxcs" { value = module.pve_01.lxcs }
output "pve_02_vms" { value = module.pve_02.vms }
output "pve_02_lxcs" { value = module.pve_02.lxcs }
output "pve_03_vms" { value = module.pve_03.vms }
output "pve_03_lxcs" { value = module.pve_03.lxcs }
