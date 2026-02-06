variable "talos_image_file_id" {
  description = "Proxmox file_id of Talos image (e.g. local:iso/talos-1.10.6-amd64.img). Upload the image to Proxmox beforehand."
  type        = string
}

variable "talos_cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
}

variable "talos_version" {
  description = "Talos version"
  type        = string
}

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
}

variable "proxmox_username" {
  description = "Proxmox API username (e.g. root@pam)"
  type        = string
  sensitive   = true
}

variable "proxmox_password" {
  description = "Proxmox API password"
  type        = string
  sensitive   = true
}

variable "proxmox_iso_datastore" {
  description = "Datastore for Talos image"
  type        = string
}

variable "proxmox_image_datastore" {
  description = "Datastore for VM disks"
  type        = string
}

variable "proxmox_control_vm_cores" {
  description = "Number of CPU cores for control plane VMs"
  type        = number
}

variable "proxmox_worker_vm_cores" {
  description = "Number of CPU cores for worker VMs"
  type        = number
}

variable "proxmox_control_vm_memory" {
  description = "Memory in MB for control plane VMs"
  type        = number
}

variable "proxmox_worker_vm_memory" {
  description = "Memory in MB for worker VMs"
  type        = number
}

variable "proxmox_vm_type" {
  description = "CPU type for VMs (e.g. x86-64-v2-AES)"
  type        = string
}

variable "proxmox_control_vm_disk_size" {
  description = "Disk size in GB for control plane VMs"
  type        = number
}

variable "proxmox_worker_vm_disk_size" {
  description = "Disk size in GB for worker VMs"
  type        = number
}

variable "proxmox_network_bridge" {
  description = "Network bridge for VMs"
  type        = string
}

variable "proxmox_network_vlan_id" {
  description = "VLAN ID for VMs (null if not used)"
  type        = number
  default     = null
}

variable "control_nodes" {
  description = "Map of Talos control node name -> Proxmox node"
  type        = map(string)
}

variable "worker_nodes" {
  description = "Map of Talos worker node name -> Proxmox node"
  type        = map(string)
}

variable "control_machine_config_patches" {
  description = "Additional machine configuration patches for control plane nodes (base CNI config is applied automatically)"
  type        = list(string)
  default     = []
}

variable "worker_machine_config_patches" {
  description = "Additional machine configuration patches for worker nodes (base CNI config is applied automatically)"
  type        = list(string)
  default     = []
}
