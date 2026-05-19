variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL."
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS verification."
  type        = bool
  default     = false
}

variable "proxmox_api_token" {
  description = "Proxmox API token."
  type        = string
  sensitive   = true
  default     = null
}

variable "proxmox_username" {
  description = "Proxmox username."
  type        = string
  default     = "terraform@pam"
}

variable "proxmox_password" {
  description = "Proxmox password."
  type        = string
  sensitive   = true
  default     = null
}

variable "ssh_keys" {
  description = "SSH public keys for container root."
  type        = list(string)
  default     = []
}
