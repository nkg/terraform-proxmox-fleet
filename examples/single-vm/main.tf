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

# Smallest viable composition: one VM, existing template, no extras.
module "fleet" {
  source = "../.."

  node_name = "proxmox-01"
  gateway   = "172.16.0.1"
  ssh_keys  = var.ssh_keys

  template = {
    id = 9000
  }

  vms = {
    "vm-01" = {
      name       = "vm-01"
      vm_id      = 200
      ip_address = "172.16.0.101/24"
    }
  }
}

output "vms" {
  value = module.fleet.vms
}
