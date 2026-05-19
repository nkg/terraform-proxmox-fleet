# tflint config — minimal, just the core ruleset for now. Add provider
# plugins (e.g. `plugin "aws"`) if/when this module grows additional
# providers; bpg/proxmox doesn't ship a tflint plugin.

config {
  format     = "compact"
  call_module_type = "all"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
