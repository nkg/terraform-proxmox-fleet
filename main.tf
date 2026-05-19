locals {
  effective_template_id = (
    var.template == null
    ? null
    : (try(var.template.id, null) != null
      ? var.template.id
      : module.template[0].template_id
    )
  )
}

# ─── Optional template build ─────────────────────────────────────────

module "template" {
  source = "./modules/template"
  count  = try(var.template.create, null) != null ? 1 : 0

  node_name = var.node_name
  vm_id     = var.template.create.vm_id
  name      = var.template.create.name

  cloud_image_url = var.template.create.cloud_image_url
  image_file_name = var.template.create.image_file_name
  image_datastore = var.template.create.image_datastore
  disk_datastore  = coalesce(var.template.create.disk_datastore, var.vm_storage)
  bridge          = var.bridge
}

# ─── VMs ─────────────────────────────────────────────────────────────

module "vm" {
  source   = "./modules/vm"
  for_each = var.vms

  node_name   = var.node_name
  vm_id       = each.value.vm_id
  name        = each.value.name
  template_id = local.effective_template_id

  cores     = each.value.cores
  memory    = each.value.memory
  disk_size = each.value.disk_size
  storage   = coalesce(each.value.storage, var.vm_storage)

  bridge  = coalesce(each.value.bridge, var.bridge)
  vlan_id = each.value.vlan_id != null ? each.value.vlan_id : var.default_vlan_id

  ip_address = each.value.ip_address
  gateway    = coalesce(each.value.gateway, var.gateway)
  ssh_keys   = coalesce(each.value.ssh_keys, var.ssh_keys)

  tags        = each.value.tags
  extra_disks = each.value.extra_disks

  extra_runcmd       = each.value.extra_runcmd
  snippets_datastore = var.snippets_datastore
}

# ─── LXCs ────────────────────────────────────────────────────────────

module "lxc" {
  source   = "./modules/lxc"
  for_each = var.lxcs

  node_name        = var.node_name
  vm_id            = each.value.vm_id
  hostname         = each.value.hostname
  template_file_id = each.value.template_file_id

  cores     = each.value.cores
  memory    = each.value.memory
  swap      = each.value.swap
  disk_size = each.value.disk_size
  storage   = coalesce(each.value.storage, var.lxc_storage)

  bridge     = coalesce(each.value.bridge, var.bridge)
  vlan_id    = each.value.vlan_id != null ? each.value.vlan_id : var.default_vlan_id
  ip_address = each.value.ip_address
  gateway    = coalesce(each.value.gateway, var.gateway)
  nameserver = each.value.nameserver
  ssh_keys   = coalesce(each.value.ssh_keys, var.ssh_keys)

  unprivileged  = each.value.unprivileged
  nesting       = each.value.nesting
  fuse          = each.value.fuse
  keyctl        = each.value.keyctl
  start_on_boot = each.value.start_on_boot

  tags         = each.value.tags
  mount_points = each.value.mount_points
}
