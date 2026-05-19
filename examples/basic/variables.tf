variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL (e.g. `https://proxmox.example:8006`)."
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS verification against the Proxmox API. Set true for self-signed."
  type        = bool
  default     = false
}

variable "proxmox_api_token" {
  description = <<-EOT
    Proxmox API token in `user@realm!tokenname=secret-value` form.

    Preferred over user/pass — tokens are revocable per-name and don't
    depend on a Proxmox web session. Source via TF_VAR_proxmox_api_token
    (or PROXMOX_VE_API_TOKEN, which the bpg provider reads natively
    when this variable is null).
  EOT
  type        = string
  sensitive   = true
  default     = null
}

variable "proxmox_username" {
  description = "Proxmox username (`user@realm`). Used only when `proxmox_api_token` is null."
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
  description = "SSH public keys for the `deploy` user inside the runner VM."
  type        = list(string)
  default     = []
}
