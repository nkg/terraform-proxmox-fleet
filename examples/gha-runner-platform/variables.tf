variable "proxmox_insecure" {
  description = "Skip TLS verification (self-signed certs)."
  type        = bool
  default     = false
}

variable "vaterland_endpoint" {
  description = "Proxmox API endpoint for the vaterland host."
  type        = string
}

variable "vaterland_api_token" {
  description = "API token for the vaterland host."
  type        = string
  sensitive   = true
}

variable "linkstation_endpoint" {
  description = "Proxmox API endpoint for the LinkStation N2 host."
  type        = string
}

variable "linkstation_api_token" {
  description = "API token for the LinkStation N2 host."
  type        = string
  sensitive   = true
}

variable "n100_b_endpoint" {
  description = "Proxmox API endpoint for the second N100 host."
  type        = string
}

variable "n100_b_api_token" {
  description = "API token for the second N100 host."
  type        = string
  sensitive   = true
}

variable "ssh_keys" {
  description = "SSH public keys baked into cloud-init / LXC config across the fleet."
  type        = list(string)
  default     = []
}
