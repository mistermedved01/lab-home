# ============================================================================
# Модуль создания виртуальных машин
# ============================================================================
# Использует модуль base-vm-cloudinit для создания VM в Proxmox с cloud-init
# конфигурацией. Модуль создает все VM из vm_list, настраивает сеть и
# применяет cloud-init шаблоны для начальной конфигурации.
# ============================================================================
module "vm-cloudinit" {
  source = "../modules/base-vm-cloudinit"

  # Параметры подключения к Proxmox
  proxmox_endpoint    = var.proxmox_endpoint
  proxmox_api_token   = var.proxmox_api_token
  node_name           = var.node_name
  datastore_id        = var.datastore_id
  network_bridge      = var.network_bridge

  # Параметры VM
  ssh_authorized_keys = [var.ssh_public_key]
  vm_user             = var.vm_user
  ansible_version     = var.ansible_version
  vm_list             = var.vm_list

  # Сетевые параметры
  gateway_ip            = var.gateway_ip
  network_cidr          = var.network_cidr

  # Параметры ISO образа
  iso_image             = var.iso_image
  snippets_datastore_id = var.snippets_datastore_id
  disk_datastore_id     = var.datastore_id
}

# ============================================================================
# Генерация Ansible Inventory
# ============================================================================
# Автоматически генерирует inventory файл для Ansible на основе созданных VM.
# Файл создается в директории 02-ansible/inventory/prod/hosts.yaml и содержит
# группировку хостов по ролям (k8s_control, k8s_worker, ansible).
# ============================================================================
resource "local_file" "ansible_inventory" {
  filename = "${path.root}/../../../../02-ansible/inventory/prod/hosts.yaml"

  content = templatefile(
    "${path.root}/templates/ansible_inventory.yaml.tftpl",
    {
      inventory        = var.vm_list
      vm_user          = var.vm_user
      proxmox_ip       = regex("^https?://([^:/]+)", var.proxmox_endpoint)[0]
      proxmox_hostname = var.node_name
    }
  )
}

# ============================================================================
# Локальные значения
# ============================================================================
# Вычисляемые значения для использования в других ресурсах
# ============================================================================
locals {
  # Получаем конфигурацию Ansible control VM из vm_list
  ansible_control_vm = var.vm_list[var.ansible_control_vm_key]
  
  # IP адрес Ansible control VM для подключения
  ansible_host_ip = local.ansible_control_vm.vm_ip
  
  # Получаем первую control plane ноду для копирования Applications
  k8s_control_plane_vm = {
    for k, vm in var.vm_list : k => vm
    if vm.role == "k8s_control"
  }
  k8s_control_plane_ip = length(local.k8s_control_plane_vm) > 0 ? values(local.k8s_control_plane_vm)[0].vm_ip : null
  
  # Полный путь к SSH ключу для подключения
  ssh_key_full_path = "${path.root}/${var.ansible_ssh_key_path}"
  
  # SSH пользователь (используем vm_user если не указан отдельно)
  ansible_ssh_user = var.ansible_ssh_user != null ? var.ansible_ssh_user : var.vm_user
}

# ============================================================================
# Копирование файлов на Ansible Control VM
# ============================================================================
# После создания VM и генерации inventory, автоматически копирует необходимые
# файлы на Ansible control VM:
# - Inventory файл (hosts.yaml)
# - Ansible playbooks и roles
# - Helm values файлы
# - SSH ключи для доступа к другим VM
#
# Скрипт также настраивает структуру директорий и права доступа на удаленном хосте.
# ============================================================================
resource "null_resource" "push_ansible_files" {
  # Зависимости: VM должны быть созданы и inventory сгенерирован
  depends_on = [module.vm-cloudinit, local_file.ansible_inventory]

  # Триггеры для повторного выполнения при изменении:
  # - Содержимое inventory
  # - Список созданных VM
  # - IP адрес Ansible control VM
  # - Содержимое playbooks и helm директорий (по хешам файлов)
  triggers = {
    inventory_content = local_file.ansible_inventory.content
    vm_ready          = join(",", keys(var.vm_list))
    ansible_host      = local.ansible_host_ip
    playbooks_dir     = sha256(join("", [for f in fileset("${path.root}/../../../../02-ansible/playbooks", "**") : filesha256("${path.root}/../../../../02-ansible/playbooks/${f}")]))
  }

  # Выполнение скрипта копирования файлов
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
# Копирует директорию 03-argocd напрямую на control plane ноду,
# где они будут применяться через kubectl.
# ============================================================================
resource "null_resource" "push_argocd_applications" {
  # Зависимости: VM должны быть созданы
  depends_on = [module.vm-cloudinit]

  # Триггеры для повторного выполнения при изменении Applications
  triggers = {
    vm_ready          = join(",", keys(var.vm_list))
    control_plane_ip  = local.k8s_control_plane_ip
    argocd_apps_dir   = sha256(join("", [for f in fileset("${path.root}/../../../../03-argocd", "**") : filesha256("${path.root}/../../../../03-argocd/${f}")]))
  }

  # Выполнение скрипта копирования Applications на control plane
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
