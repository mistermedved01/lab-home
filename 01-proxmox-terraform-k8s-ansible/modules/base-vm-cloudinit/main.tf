resource "proxmox_virtual_environment_file" "cloudinit_config" {
  for_each     = var.vm_list
  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  node_name    = var.node_name

  source_raw {
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

resource "proxmox_virtual_environment_vm" "vm-cloudinit" {
  for_each  = var.vm_list
  name      = each.value.vm_hostname
  node_name = var.node_name
  vm_id     = each.value.vm_id

  clone {
    vm_id = var.template_vm_id
    # Опционально: если шаблон на другом хранилище, или хочешь сразу мигрировать
    # datastore_id = var.disk_datastore_id  # ← укажи, если нужно
    full      = true  # full clone (рекомендую, linked иногда глючит)
  }

  cpu {
    cores = each.value.vm_cores
  }

  memory {
    dedicated = each.value.vm_memory
  }

  # ← Вот этот блок — ключевой! Он заставит провайдер изменить размер диска после клонирования
  disk {
    datastore_id = var.disk_datastore_id
    interface    = "scsi0"              # ← проверь в шаблоне, обычно scsi0 или virtio0
    size         = each.value.vm_disk_size
    # Опционально, но полезно:
    iothread     = true
    discard      = "on"                 # trim для SSD
    file_format  = "raw"                # или qcow2
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.vm_ip}/${var.network_cidr}"
        gateway = var.gateway_ip
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.cloudinit_config[each.key].id
  }

  started = true
}