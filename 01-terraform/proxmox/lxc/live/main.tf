locals {
  ssh_keys = [trimspace(var.ssh_public_key)]

  lxc_pve01 = { for k, v in var.lxc_list : k => v if v.proxmox_node == "pve-node-01" }
  lxc_pve02 = { for k, v in var.lxc_list : k => v if v.proxmox_node == "pve-node-02" }
  lxc_pve03 = { for k, v in var.lxc_list : k => v if v.proxmox_node == "pve-node-03" }
}

module "lxc_pve_node_01" {
  source = "../modules/base-lxc"
  providers = {
    proxmox = proxmox.pve_node_01
  }

  for_each = local.lxc_pve01

  node_name    = var.proxmox_nodes["pve-node-01"].node_name
  datastore_id = var.proxmox_nodes["pve-node-01"].datastore_id
  bridge       = var.proxmox_nodes["pve-node-01"].network_bridge

  vm_id            = each.value.vm_id
  hostname         = each.value.hostname
  description      = coalesce(each.value.description, "Managed by Terraform (lab-home lxc/${each.key})")
  template_file_id = each.value.template_file_id
  os_type          = each.value.os_type

  ipv4_address        = each.value.ipv4_address
  network_cidr_bits   = var.network_cidr_bits
  ipv4_gateway        = var.gateway_ip
  dns_servers         = coalesce(each.value.dns_servers_override, var.dns_servers)
  ssh_public_keys     = local.ssh_keys
  cpu_cores           = each.value.cpu_cores
  memory_mb           = each.value.memory_mb
  rootfs_gb           = each.value.rootfs_gb
  unprivileged        = each.value.unprivileged
  nesting             = each.value.nesting
  fuse                = coalesce(each.value.fuse, false)
  keyctl              = coalesce(each.value.keyctl, false)
  network_interface_name = each.value.network_interface
  wait_for_ipv4       = coalesce(each.value.wait_for_ipv4, true)
}

module "lxc_pve_node_02" {
  source = "../modules/base-lxc"
  providers = {
    proxmox = proxmox.pve_node_02
  }

  for_each = local.lxc_pve02

  node_name    = var.proxmox_nodes["pve-node-02"].node_name
  datastore_id = var.proxmox_nodes["pve-node-02"].datastore_id
  bridge       = var.proxmox_nodes["pve-node-02"].network_bridge

  vm_id            = each.value.vm_id
  hostname         = each.value.hostname
  description      = coalesce(each.value.description, "Managed by Terraform (lab-home lxc/${each.key})")
  template_file_id = each.value.template_file_id
  os_type          = each.value.os_type

  ipv4_address        = each.value.ipv4_address
  network_cidr_bits   = var.network_cidr_bits
  ipv4_gateway        = var.gateway_ip
  dns_servers         = coalesce(each.value.dns_servers_override, var.dns_servers)
  ssh_public_keys     = local.ssh_keys
  cpu_cores           = each.value.cpu_cores
  memory_mb           = each.value.memory_mb
  rootfs_gb           = each.value.rootfs_gb
  unprivileged        = each.value.unprivileged
  nesting             = each.value.nesting
  fuse                = coalesce(each.value.fuse, false)
  keyctl              = coalesce(each.value.keyctl, false)
  network_interface_name = each.value.network_interface
  wait_for_ipv4       = coalesce(each.value.wait_for_ipv4, true)
}

module "lxc_pve_node_03" {
  source = "../modules/base-lxc"
  providers = {
    proxmox = proxmox.pve_node_03
  }

  for_each = local.lxc_pve03

  node_name    = var.proxmox_nodes["pve-node-03"].node_name
  datastore_id = var.proxmox_nodes["pve-node-03"].datastore_id
  bridge       = var.proxmox_nodes["pve-node-03"].network_bridge

  vm_id            = each.value.vm_id
  hostname         = each.value.hostname
  description      = coalesce(each.value.description, "Managed by Terraform (lab-home lxc/${each.key})")
  template_file_id = each.value.template_file_id
  os_type          = each.value.os_type

  ipv4_address        = each.value.ipv4_address
  network_cidr_bits   = var.network_cidr_bits
  ipv4_gateway        = var.gateway_ip
  dns_servers         = coalesce(each.value.dns_servers_override, var.dns_servers)
  ssh_public_keys     = local.ssh_keys
  cpu_cores           = each.value.cpu_cores
  memory_mb           = each.value.memory_mb
  rootfs_gb           = each.value.rootfs_gb
  unprivileged        = each.value.unprivileged
  nesting             = each.value.nesting
  fuse                = coalesce(each.value.fuse, false)
  keyctl              = coalesce(each.value.keyctl, false)
  network_interface_name = each.value.network_interface
  wait_for_ipv4       = coalesce(each.value.wait_for_ipv4, true)
}
