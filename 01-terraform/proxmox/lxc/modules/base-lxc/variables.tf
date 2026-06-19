variable "node_name" {
  description = "Имя узла Proxmox PVE (как в Datacenter → кластер)"
  type        = string
}

variable "datastore_id" {
  description = "Хранилище для rootfs CT (как в vm-ubuntu: local, local-lvm, …)"
  type        = string
}

variable "bridge" {
  description = "Linux bridge для первого интерфейса (обычно vmbr0)"
  type        = string
  default     = "vmbr0"
}

variable "vm_id" {
  description = "VMID контейнера в Proxmox"
  type        = number
}

variable "hostname" {
  description = "Hostname внутри CT"
  type        = string
}

variable "description" {
  description = "Описание CT в Proxmox"
  type        = string
  default     = "Managed by Terraform (lab-home base-lxc)"
}

variable "template_file_id" {
  description = "Шаблон LXC: storage:content, напр. local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst (pvesm list <storage> --content vztmpl)"
  type        = string
}

variable "os_type" {
  description = "Тип ОС для PVE (ubuntu, debian, …). См. operating_system.type в провайдере bpg/proxmox"
  type        = string
  default     = "ubuntu"
}

variable "ipv4_address" {
  description = "IPv4 хоста без маски (маска задаётся отдельно)"
  type        = string
}

variable "network_cidr_bits" {
  description = "Длина префикса IPv4 (например 24 для /24)"
  type        = number
}

variable "ipv4_gateway" {
  description = "Шлюз по умолчанию"
  type        = string
}

variable "dns_servers" {
  description = "DNS для CT; пустой список — блок dns не создаётся"
  type        = list(string)
  default     = []
}

variable "ssh_public_keys" {
  description = "SSH публичные ключи для root внутри CT (initialization.user_account.keys)"
  type        = list(string)
}

variable "cpu_cores" {
  type    = number
  default = 2
}

variable "memory_mb" {
  type    = number
  default = 2048
}

variable "rootfs_gb" {
  description = "Размер корневого диска CT, ГБ"
  type        = number
  default     = 16
}

variable "unprivileged" {
  type    = bool
  default = true
}

variable "nesting" {
  description = "Включить nesting (Docker в CT и т.п.)"
  type        = bool
  default     = false
}

variable "fuse" {
  description = "FUSE в CT (часто нужно вместе с nesting для Docker/overlay в unprivileged LXC)"
  type        = bool
  default     = false
}

variable "keyctl" {
  description = "keyctl в CT (иногда требуется для контейнерных рантаймов)"
  type        = bool
  default     = false
}

variable "network_interface_name" {
  description = "Имя интерфейса в госте (часто eth0; если нет сети — см. доку Proxmox для шаблона)"
  type        = string
  default     = "eth0"
}

variable "wait_for_ipv4" {
  description = "Ждать выдачи IPv4 при старте (полезно при статической настройке)"
  type        = bool
  default     = true
}
