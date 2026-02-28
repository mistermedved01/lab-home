# ============================================================================
# Модули создания виртуальных машин (по одному на узел Proxmox)
# ============================================================================
# Каждый вызов модуля создаёт VM на одном узле. vm_list фильтруется по proxmox_node.
# В модуль передаётся только подмножество атрибутов, ожидаемых base-vm-cloudinit.
# ============================================================================

locals {
  vm_list_for_module = {
    for k, v in var.vm_list : k => {
      vm_hostname     = v.vm_hostname
      vm_ip           = v.vm_ip
      vm_id           = v.vm_id
      vm_cores        = v.vm_cores
      vm_memory       = v.vm_memory
      vm_disk_size    = v.vm_disk_size
      cloud_init_file = v.cloud_init_file
    }
  }
  vm_list_pve01 = { for k, v in local.vm_list_for_module : k => v if var.vm_list[k].proxmox_node == "pve-node-01" }
  vm_list_pve02 = { for k, v in local.vm_list_for_module : k => v if var.vm_list[k].proxmox_node == "pve-node-02" }
  vm_list_pve03 = { for k, v in local.vm_list_for_module : k => v if var.vm_list[k].proxmox_node == "pve-node-03" }
}

module "vm_cloudinit_pve_node_01" {
  source   = "../modules/base-vm-cloudinit"
  providers = {
    proxmox = proxmox.pve_node_01
  }

  proxmox_endpoint    = var.proxmox_nodes["pve-node-01"].endpoint
  proxmox_api_token   = var.proxmox_nodes["pve-node-01"].api_token
  node_name           = var.proxmox_nodes["pve-node-01"].node_name
  datastore_id        = var.proxmox_nodes["pve-node-01"].datastore_id
  network_bridge      = var.proxmox_nodes["pve-node-01"].network_bridge

  ssh_authorized_keys = [var.ssh_public_key]
  vm_user             = var.vm_user
  ansible_version     = var.ansible_version
  vm_list             = local.vm_list_pve01

  gateway_ip            = var.gateway_ip
  network_cidr          = var.network_cidr
  iso_image             = var.iso_image
  snippets_datastore_id = var.snippets_datastore_id
  disk_datastore_id     = var.proxmox_nodes["pve-node-01"].datastore_id
}

module "vm_cloudinit_pve_node_02" {
  source   = "../modules/base-vm-cloudinit"
  providers = {
    proxmox = proxmox.pve_node_02
  }

  proxmox_endpoint    = var.proxmox_nodes["pve-node-02"].endpoint
  proxmox_api_token   = var.proxmox_nodes["pve-node-02"].api_token
  node_name           = var.proxmox_nodes["pve-node-02"].node_name
  datastore_id        = var.proxmox_nodes["pve-node-02"].datastore_id
  network_bridge      = var.proxmox_nodes["pve-node-02"].network_bridge

  ssh_authorized_keys = [var.ssh_public_key]
  vm_user             = var.vm_user
  ansible_version     = var.ansible_version
  vm_list             = local.vm_list_pve02

  gateway_ip            = var.gateway_ip
  network_cidr          = var.network_cidr
  iso_image             = var.iso_image
  snippets_datastore_id = var.snippets_datastore_id
  disk_datastore_id     = var.proxmox_nodes["pve-node-02"].datastore_id
}

module "vm_cloudinit_pve_node_03" {
  source   = "../modules/base-vm-cloudinit"
  providers = {
    proxmox = proxmox.pve_node_03
  }

  proxmox_endpoint    = var.proxmox_nodes["pve-node-03"].endpoint
  proxmox_api_token   = var.proxmox_nodes["pve-node-03"].api_token
  node_name           = var.proxmox_nodes["pve-node-03"].node_name
  datastore_id        = var.proxmox_nodes["pve-node-03"].datastore_id
  network_bridge      = var.proxmox_nodes["pve-node-03"].network_bridge

  ssh_authorized_keys = [var.ssh_public_key]
  vm_user             = var.vm_user
  ansible_version     = var.ansible_version
  vm_list             = local.vm_list_pve03

  gateway_ip            = var.gateway_ip
  network_cidr          = var.network_cidr
  iso_image             = var.iso_image
  snippets_datastore_id = var.snippets_datastore_id
  disk_datastore_id     = var.proxmox_nodes["pve-node-03"].datastore_id
}

# ============================================================================
# Генерация Ansible Inventory
# ============================================================================
# Один общий inventory: все VM из vm_list, группа proxmox — все узлы из proxmox_nodes.
# ============================================================================
locals {
  proxmox_hosts = [
    for name, cfg in var.proxmox_nodes : {
      hostname = name
      ip       = regex("^https?://([^:/]+)", cfg.endpoint)[0]
    }
  ]
}

resource "local_file" "ansible_inventory" {
  filename = "${path.root}/../../../../02-ansible/inventory/prod/hosts.yaml"

  content = templatefile(
    "${path.root}/templates/ansible_inventory.yaml.tftpl",
    {
      inventory     = var.vm_list
      vm_user       = var.vm_user
      proxmox_hosts = local.proxmox_hosts
    }
  )
}

# ============================================================================
# Локальные значения
# ============================================================================
locals {
  merged_vms_by_hostname = merge(
    module.vm_cloudinit_pve_node_01.vms_by_hostname,
    module.vm_cloudinit_pve_node_02.vms_by_hostname,
    module.vm_cloudinit_pve_node_03.vms_by_hostname
  )

  ansible_control_vm   = var.vm_list[var.ansible_control_vm_key]
  ansible_host_ip     = local.ansible_control_vm.vm_ip

  k8s_control_plane_vm = {
    for k, vm in var.vm_list : k => vm
    if vm.role == "k8s_control"
  }
  k8s_control_plane_ip = length(local.k8s_control_plane_vm) > 0 ? values(local.k8s_control_plane_vm)[0].vm_ip : null

  ssh_key_full_path = "${path.root}/${var.ansible_ssh_key_path}"
  ansible_ssh_user  = var.ansible_ssh_user != null ? var.ansible_ssh_user : var.vm_user
}

# ============================================================================
# Копирование файлов на Ansible Control VM
# ============================================================================
resource "null_resource" "push_ansible_files" {
  depends_on = [module.vm_cloudinit_pve_node_01, module.vm_cloudinit_pve_node_02, module.vm_cloudinit_pve_node_03, local_file.ansible_inventory]

  triggers = {
    inventory_content = local_file.ansible_inventory.content
    vm_ready         = join(",", keys(var.vm_list))
    ansible_host     = local.ansible_host_ip
    playbooks_dir    = sha256(join("", [for f in fileset("${path.root}/../../../../02-ansible/playbooks", "**") : filesha256("${path.root}/../../../../02-ansible/playbooks/${f}")]))
  }

  provisioner "local-exec" {
    command = <<-EOT
      chmod +x "${path.root}/scripts/push_ansible_files.sh" && \
      "${path.root}/scripts/push_ansible_files.sh" \
        "${local.ansible_host_ip}" \
        "${local.ansible_ssh_user}" \
        "${local.ssh_key_full_path}" \
        "${path.root}/../../../../02-ansible/inventory/prod/hosts.yaml" \
        "${local.ssh_key_full_path}" \
        "${path.root}/../../../../02-ansible" \
        ""
    EOT

    interpreter = ["bash", "-c"]
  }
}

# ============================================================================
# Копирование ArgoCD Applications на Control Plane ноду
# ============================================================================
resource "null_resource" "push_argocd_applications" {
  depends_on = [module.vm_cloudinit_pve_node_01, module.vm_cloudinit_pve_node_02, module.vm_cloudinit_pve_node_03]

  triggers = {
    vm_ready         = join(",", keys(var.vm_list))
    control_plane_ip = local.k8s_control_plane_ip
    argocd_apps_dir  = sha256(join("", [for f in fileset("${path.root}/../../../../03-argocd", "**") : filesha256("${path.root}/../../../../03-argocd/${f}")]))
  }

  provisioner "local-exec" {
    command = <<-EOT
      chmod +x "${path.root}/scripts/push_argocd_applications.sh" && \
      "${path.root}/scripts/push_argocd_applications.sh" \
        "${local.k8s_control_plane_ip}" \
        "${local.ansible_ssh_user}" \
        "${local.ssh_key_full_path}" \
        "${abspath("${path.root}/../../../../03-argocd")}"
    EOT

    interpreter = ["bash", "-c"]
  }
}
