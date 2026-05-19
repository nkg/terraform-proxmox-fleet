variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL (e.g. `https://proxmox.example:8006`)."
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (self-signed certs)."
  type        = bool
  default     = false
}

variable "proxmox_api_token" {
  description = "Proxmox API token (`user@realm!tokenname=secret`). Source via TF_VAR_proxmox_api_token."
  type        = string
  sensitive   = true
  default     = null
}

variable "proxmox_username" {
  description = "Proxmox username. Used only when `proxmox_api_token` is null."
  type        = string
  default     = "terraform@pam"
}

variable "proxmox_password" {
  description = "Proxmox password. Used only when `proxmox_api_token` is null."
  type        = string
  sensitive   = true
  default     = null
}

variable "ssh_keys" {
  description = "SSH public keys for the `deploy` user."
  type        = list(string)
  default     = []
}
