# Outputs модуля base-vm-cloudinit
# Экспортирует информацию о созданных VM для использования в других модулях или root модуле

# Map всех созданных VM с их основными параметрами
output "vms" {
  description = "Map всех созданных VM с их параметрами"
  value = {
    for k, vm in proxmox_virtual_environment_vm.vm-cloudinit : k => {
      id       = vm.vm_id
      name     = vm.name
      node     = vm.node_name
      ipv4     = vm.initialization[0].ip_config[0].ipv4[0].address
      hostname = vm.name
    }
  }
}

# Map VM по их hostname для удобного поиска
output "vms_by_hostname" {
  description = "Map VM по hostname для удобного поиска"
  value = {
    for k, vm in proxmox_virtual_environment_vm.vm-cloudinit : vm.name => {
      key        = k
      id         = vm.vm_id
      node       = vm.node_name
      ipv4       = vm.initialization[0].ip_config[0].ipv4[0].address
      cores      = vm.cpu[0].cores
      memory_mb  = vm.memory[0].dedicated
      disk_size_gb = vm.disk[0].size
    }
  }
}

# Список всех IP адресов созданных VM
output "vm_ips" {
  description = "Список всех IP адресов созданных VM"
  value = [
    for vm in proxmox_virtual_environment_vm.vm-cloudinit : 
    vm.initialization[0].ip_config[0].ipv4[0].address
  ]
}

# Map IP адресов к hostname
output "vm_ips_map" {
  description = "Map IP адресов к hostname VM"
  value = {
    for vm in proxmox_virtual_environment_vm.vm-cloudinit :
    vm.initialization[0].ip_config[0].ipv4[0].address => vm.name
  }
}

# Map VM IDs к hostname
output "vm_ids_map" {
  description = "Map VM IDs к hostname"
  value = {
    for vm in proxmox_virtual_environment_vm.vm-cloudinit :
    vm.vm_id => vm.name
  }
}

# Cloud-init файлы, которые были созданы
output "cloudinit_files" {
  description = "Map cloud-init файлов, созданных для каждой VM"
  value = {
    for k, file in proxmox_virtual_environment_file.cloudinit_config : k => {
      id         = file.id
      datastore  = file.datastore_id
      file_name  = file.source_raw[0].file_name
    }
  }
}

