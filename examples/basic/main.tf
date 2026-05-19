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

  # Prefer API token; fall back to user/pass.
  api_token = var.proxmox_api_token
  username  = var.proxmox_api_token == null ? var.proxmox_username : null
  password  = var.proxmox_api_token == null ? var.proxmox_password : null

  ssh {
    agent = true
  }
}

module "runner" {
  # Bump to a tagged release once published; tracking main here is
  # fine for an in-repo example that doubles as an integration test.
  source = "../.."

  node_name   = "proxmox-01"
  vm_id       = 200
  name        = "runner-01"
  template_id = 9000
  ip_address  = "172.16.0.101/24"
  gateway     = "172.16.0.1"

  # ssh-ed25519 ... your@host  — keys baked into cloud-init for the
  # `deploy` user. The module does not write a password, so make sure
  # at least one key is present or the VM is unreachable.
  ssh_keys = var.ssh_keys

  # Optional scratch disk on a slow-tier pool, mounted by ansible at
  # /var/lib/runner-cache. See the module's variables.tf for the
  # rationale and the full per-disk knob set.
  extra_disks = [
    { size = 300, storage = "tank", backup = false },
  ]
}

output "runner_vm_id" {
  value = module.runner.vm_id
}

output "runner_ip_address" {
  value = module.runner.ip_address
}
