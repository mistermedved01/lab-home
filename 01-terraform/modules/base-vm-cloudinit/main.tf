# ============================================================================
# Cloud-init конфигурации
# ============================================================================
# Создает cloud-init snippets для каждой VM из vm_list. Файлы загружаются
# в Proxmox datastore и используются при инициализации VM для начальной настройки.
# Шаблоны находятся в директории cloud-init/ и поддерживают переменные:
# - hostname: имя хоста VM
# - ssh_authorized_keys: список SSH ключей для доступа
# - vm_user: имя пользователя для создания
# - ansible_version: версия Ansible (для ansible-control шаблона)
# ============================================================================
resource "proxmox_virtual_environment_file" "cloudinit_config" {
  for_each     = var.vm_list
  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  node_name    = var.node_name

  source_raw {
    # Генерация cloud-init конфигурации из шаблона
    data = templatefile(
      "${path.module}/cloud-init/${each.value.cloud_init_file}",
      {
        hostname            = each.value.vm_hostname
        ssh_authorized_keys = var.ssh_authorized_keys
        vm_user             = var.vm_user
        ansible_version     = var.ansible_version
      }
    )
    file_name = "cloud-init-${each.value.vm_hostname}.yaml"
  }
}

# ============================================================================
# Виртуальные машины
# ============================================================================
# Создает виртуальные машины в Proxmox из ISO образа.
# Для каждой записи в vm_list создается отдельная VM с указанными параметрами.
# ============================================================================
resource "proxmox_virtual_environment_vm" "vm-cloudinit" {
  for_each  = var.vm_list
  name      = each.value.vm_hostname
  node_name = var.node_name
  vm_id     = each.value.vm_id

  # ========================================================================
  # CPU конфигурация
  # ========================================================================
  cpu {
    cores = each.value.vm_cores
  }

  # ========================================================================
  # Память
  # ========================================================================
  memory {
    dedicated = each.value.vm_memory
  }

  # ========================================================================
  # Диск
  # ========================================================================
  # Настройка диска VM. Диск создается из ISO образа.
  # 
  # Параметры:
  # - iothread: улучшает производительность I/O для виртуализированных дисков
  # - discard: включает TRIM для SSD (рекомендуется для SSD хранилищ)
  # - file_format: raw для лучшей производительности, qcow2 для экономии места
  # - file_id: путь к ISO образу в datastore (например, local:iso/image.img)
  # ========================================================================
  disk {
    datastore_id = var.disk_datastore_id
    interface    = "scsi0"
    size         = each.value.vm_disk_size
    iothread     = true
    discard      = "on"
    file_format  = "raw"
    file_id      = var.iso_image != null ? var.iso_image : null
  }

  # ========================================================================
  # Сетевое устройство
  # ========================================================================
  # Настройка сетевого интерфейса. Используется virtio для лучшей
  # производительности в виртуализированной среде.
  # ========================================================================
  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  # ========================================================================
  # Cloud-init инициализация
  # ========================================================================
  # Настройка начальной конфигурации через cloud-init:
  # - Статический IP адрес из vm_list
  # - Gateway и CIDR маска подсети
  # - Cloud-init конфигурация из созданного snippet файла
  # ========================================================================
  initialization {
    datastore_id      = var.snippets_datastore_id
    user_data_file_id = proxmox_virtual_environment_file.cloudinit_config[each.key].id
    ip_config {
      ipv4 {
        address = "${each.value.vm_ip}/${var.network_cidr}"
        gateway = var.gateway_ip
      }
    }
  }

  # Автоматический запуск VM после создания
  started = true
}