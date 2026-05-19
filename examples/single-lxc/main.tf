terraform {
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.106"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = var.proxmox_insecure

  api_token = var.proxmox_api_token
  username  = var.proxmox_api_token == null ? var.proxmox_username : null
  password  = var.proxmox_api_token == null ? var.proxmox_password : null

  ssh {
    agent = true
  }
}

# Smallest viable LXC composition: one unprivileged Debian container.
module "fleet" {
  source = "../.."

  node_name = "proxmox-01"
  gateway   = "192.168.1.1"
  ssh_keys  = var.ssh_keys

  # No VMs in this example, so no template needed.
  template = null

  lxcs = {
    "lxc-01" = {
      hostname         = "lxc-01"
      vm_id            = 300
      ip_address       = "192.168.1.110/24"
      template_file_id = "local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst"
    }
  }
}

output "lxcs" {
  value = module.fleet.lxcs
}
