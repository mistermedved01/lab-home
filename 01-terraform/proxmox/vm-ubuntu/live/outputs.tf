# ============================================================================
# Outputs для live конфигурации (объединённые данные по всем узлам Proxmox)
# ============================================================================

# ----------------------------------------------------------------------------
# Все созданные VM
# ----------------------------------------------------------------------------
output "vms" {
  description = "Map всех созданных VM с их параметрами"
  value       = merge(module.vm_cloudinit_pve_node_01.vms, module.vm_cloudinit_pve_node_02.vms, module.vm_cloudinit_pve_node_03.vms)
}

# ----------------------------------------------------------------------------
# VM по hostname (полные параметры: cores, memory, disk, ipv4, node)
# ----------------------------------------------------------------------------
output "vms_by_hostname" {
  description = "Map VM по hostname для удобного поиска"
  value       = local.merged_vms_by_hostname
}

# ----------------------------------------------------------------------------
# IP адрес Ansible control VM
# ----------------------------------------------------------------------------
output "ansible_control_ip" {
  description = "IP адрес Ansible control VM"
  value       = try(local.merged_vms_by_hostname[var.vm_list[var.ansible_control_vm_key].vm_hostname].ipv4, null)
}

# ----------------------------------------------------------------------------
# IP адреса Kubernetes control plane nodes
# ----------------------------------------------------------------------------
output "k8s_control_plane_ips" {
  description = "IP адреса Kubernetes control plane nodes"
  value = [
    for k, vm in var.vm_list : local.merged_vms_by_hostname[vm.vm_hostname].ipv4
    if vm.role == "k8s_control" && contains(keys(local.merged_vms_by_hostname), vm.vm_hostname)
  ]
}

# ----------------------------------------------------------------------------
# IP адреса Kubernetes worker nodes
# ----------------------------------------------------------------------------
output "k8s_worker_ips" {
  description = "IP адреса Kubernetes worker nodes"
  value = [
    for k, vm in var.vm_list : local.merged_vms_by_hostname[vm.vm_hostname].ipv4
    if vm.role == "k8s_worker" && contains(keys(local.merged_vms_by_hostname), vm.vm_hostname)
  ]
}
