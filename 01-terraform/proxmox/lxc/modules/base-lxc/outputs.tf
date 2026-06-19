output "vm_id" {
  description = "VMID контейнера"
  value       = proxmox_virtual_environment_container.this.vm_id
}

output "ipv4_by_interface" {
  description = "IPv4 по интерфейсам (атрибут провайдера)"
  value       = proxmox_virtual_environment_container.this.ipv4
}

output "primary_ipv4" {
  description = "Первый IPv4 из карты провайдера (если есть)"
  value       = try(values(proxmox_virtual_environment_container.this.ipv4)[0], null)
}
