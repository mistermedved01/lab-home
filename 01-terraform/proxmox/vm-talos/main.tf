terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.75.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.7.1"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  username  = var.proxmox_username
  password  = var.proxmox_password
  insecure  = true
}

locals {
  primary_control_node_ip = proxmox_virtual_environment_vm.talos_control_vm[keys(var.control_nodes)[0]].ipv4_addresses[7][0]
  control_node_ips        = [for vm in keys(var.control_nodes) : proxmox_virtual_environment_vm.talos_control_vm[vm].ipv4_addresses[7][0]]
  worker_node_ips         = [for vm in keys(var.worker_nodes) : proxmox_virtual_environment_vm.talos_worker_vm[vm].ipv4_addresses[7][0]]
  node_ips                = concat(local.control_node_ips, local.worker_node_ips)

  base_cni_patch = <<-EOT
cluster:
  network:
    cni:
      name: flannel
  proxy:
    disabled: false
EOT
  control_config_patches  = concat([local.base_cni_patch], var.control_machine_config_patches)
  worker_config_patches   = concat([local.base_cni_patch], var.worker_machine_config_patches)
}

resource "proxmox_virtual_environment_vm" "talos_control_vm" {
  for_each  = var.control_nodes
  name      = each.key
  node_name = each.value
  agent {
    enabled = true
  }
  cpu {
    cores = var.proxmox_control_vm_cores
    type  = var.proxmox_vm_type
  }
  memory {
    dedicated = var.proxmox_control_vm_memory
    floating  = var.proxmox_control_vm_memory
  }
  disk {
    datastore_id = var.proxmox_image_datastore
    file_id      = var.talos_image_file_id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.proxmox_control_vm_disk_size
  }
  network_device {
    vlan_id = var.proxmox_network_vlan_id
    bridge  = var.proxmox_network_bridge
  }
  operating_system {
    type = "l26"
  }
}

resource "proxmox_virtual_environment_vm" "talos_worker_vm" {
  for_each  = var.worker_nodes
  name      = each.key
  node_name = each.value
  agent {
    enabled = true
  }
  cpu {
    cores = var.proxmox_worker_vm_cores
    type  = var.proxmox_vm_type
  }
  memory {
    dedicated = var.proxmox_worker_vm_memory
    floating  = var.proxmox_worker_vm_memory
  }
  disk {
    datastore_id = var.proxmox_image_datastore
    file_id      = var.talos_image_file_id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.proxmox_worker_vm_disk_size
  }
  network_device {
    vlan_id = var.proxmox_network_vlan_id
    bridge  = var.proxmox_network_bridge
  }
  operating_system {
    type = "l26"
  }
}

resource "talos_machine_secrets" "talos_secrets" {}

data "talos_machine_configuration" "control_mc" {
  cluster_name     = var.talos_cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${local.primary_control_node_ip}:6443"
  machine_secrets  = talos_machine_secrets.talos_secrets.machine_secrets
}

data "talos_machine_configuration" "worker_mc" {
  cluster_name     = var.talos_cluster_name
  machine_type     = "worker"
  cluster_endpoint = "https://${local.primary_control_node_ip}:6443"
  machine_secrets  = talos_machine_secrets.talos_secrets.machine_secrets
}

data "talos_client_configuration" "talos_client_config" {
  cluster_name         = var.talos_cluster_name
  client_configuration = talos_machine_secrets.talos_secrets.client_configuration
  endpoints            = local.control_node_ips
  nodes                = local.node_ips
}

resource "talos_machine_configuration_apply" "talos_control_mc_apply" {
  for_each                   = var.control_nodes
  client_configuration       = talos_machine_secrets.talos_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_mc.machine_configuration
  node                       = proxmox_virtual_environment_vm.talos_control_vm[each.key].ipv4_addresses[7][0]
  config_patches             = local.control_config_patches
}

resource "talos_machine_configuration_apply" "talos_worker_mc_apply" {
  for_each                   = var.worker_nodes
  client_configuration       = talos_machine_secrets.talos_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker_mc.machine_configuration
  node                       = proxmox_virtual_environment_vm.talos_worker_vm[each.key].ipv4_addresses[7][0]
  config_patches             = local.worker_config_patches
}

resource "talos_machine_bootstrap" "talos_bootstrap" {
  node                 = local.primary_control_node_ip
  client_configuration = talos_machine_secrets.talos_secrets.client_configuration
}

resource "talos_cluster_kubeconfig" "talos_kubeconfig" {
  depends_on = [talos_machine_bootstrap.talos_bootstrap]

  client_configuration = talos_machine_secrets.talos_secrets.client_configuration
  node                 = local.primary_control_node_ip
}
