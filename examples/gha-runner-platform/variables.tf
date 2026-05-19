variable "proxmox_insecure" {
  description = "Skip TLS verification (self-signed certs)."
  type        = bool
  default     = false
}

variable "pve_01_endpoint" {
  description = "Proxmox API endpoint for the pve-01 host."
  type        = string
}

variable "pve_01_api_token" {
  description = "API token for the pve-01 host."
  type        = string
  sensitive   = true
}

variable "pve_02_endpoint" {
  description = "Proxmox API endpoint for the pve-02 host."
  type        = string
}

variable "pve_02_api_token" {
  description = "API token for the pve-02 host."
  type        = string
  sensitive   = true
}

variable "pve_03_endpoint" {
  description = "Proxmox API endpoint for the pve-03 host."
  type        = string
}

variable "pve_03_api_token" {
  description = "API token for the pve-03 host."
  type        = string
  sensitive   = true
}

variable "ssh_keys" {
  description = "SSH public keys baked into cloud-init / LXC config across the fleet."
  type        = list(string)
  default     = []
}
