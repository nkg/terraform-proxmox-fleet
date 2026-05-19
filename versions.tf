terraform {
  # 1.5 introduced the lifecycle `replace_triggered_by` attribute used by
  # consumers of this module; OpenTofu 1.x and Terraform 1.5+ both qualify.
  required_version = ">= 1.5"

  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      # Track the latest minor on the 0.x line. The provider is still
      # pre-1.0 so semver guarantees apply per-minor — `~> 0.106` accepts
      # 0.106.x patch bumps without picking up 0.107's potentially-breaking
      # changes automatically. Bump intentionally by widening the
      # constraint + re-running `tofu init -upgrade` in consumers.
      version = "~> 0.106"
    }
  }
}
