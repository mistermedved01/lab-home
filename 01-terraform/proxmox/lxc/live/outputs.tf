output "lxc" {
  description = "Сводка по созданным CT: VMID и первый IPv4"
  value = merge(
    { for k, m in module.lxc_pve_node_01 : k => { vm_id = m.vm_id, primary_ipv4 = m.primary_ipv4 } },
    { for k, m in module.lxc_pve_node_02 : k => { vm_id = m.vm_id, primary_ipv4 = m.primary_ipv4 } },
    { for k, m in module.lxc_pve_node_03 : k => { vm_id = m.vm_id, primary_ipv4 = m.primary_ipv4 } },
  )
}
