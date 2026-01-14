variable "proxmox_endpoint" {
  description = "URL API Proxmox (например https://192.168.40.150:8006/)"
  type        = string

  validation {
    condition     = can(regex("^https?://", var.proxmox_endpoint))
    error_message = "proxmox_endpoint должен быть валидным URL, начинающимся с http:// или https://"
  }
}

variable "proxmox_api_token" {
  description = "API token для Terraform"
  type        = string
  sensitive   = true
}

variable "node_name" {
  description = "Имя узла Proxmox"
  type        = string

  validation {
    condition     = length(var.node_name) > 0
    error_message = "node_name не может быть пустым"
  }
}

variable "datastore_id" {
  description = "Хранилище для VM дисков"
  type        = string

  validation {
    condition     = length(var.datastore_id) > 0
    error_message = "datastore_id не может быть пустым"
  }
}

variable "network_bridge" {
  description = "Сетевой мост"
  type        = string

  validation {
    condition     = can(regex("^vmbr[0-9]+$", var.network_bridge))
    error_message = "network_bridge должен быть в формате vmbr0, vmbr1, и т.д."
  }
}

variable "ssh_authorized_keys" {
  description = "Список публичных SSH ключей для VM"
  type        = list(string)

  validation {
    condition = length(var.ssh_authorized_keys) > 0
    error_message = "ssh_authorized_keys должен содержать хотя бы один ключ"
  }

  validation {
    condition = alltrue([
      for key in var.ssh_authorized_keys : can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|ssh-dss)", key))
    ])
    error_message = "Все ключи в ssh_authorized_keys должны быть валидными публичными SSH ключами"
  }
}

variable "vm_user" {
  description = "Имя пользователя для создания на VM"
  type        = string
  default     = "ubuntu"

  validation {
    condition     = length(var.vm_user) > 0 && can(regex("^[a-z_][a-z0-9_-]*$", var.vm_user))
    error_message = "vm_user должен быть валидным именем пользователя Unix"
  }
}

variable "vm_list" {
  description = "Список VM для создания"
  type = map(object({
    vm_hostname : string
    vm_ip       : string
    vm_id       : number
    vm_cores    : number
    vm_memory   : number
    vm_disk_size: number
    cloud_init_file = string
  }))

  validation {
    condition = length(var.vm_list) > 0
    error_message = "vm_list не может быть пустым"
  }

  validation {
    condition = alltrue([
      for k, v in var.vm_list : v.vm_id > 0 && v.vm_id < 100000
    ])
    error_message = "vm_id должен быть положительным числом меньше 100000"
  }

  validation {
    condition = alltrue([
      for k, v in var.vm_list : v.vm_cores > 0 && v.vm_cores <= 64
    ])
    error_message = "vm_cores должен быть положительным числом от 1 до 64"
  }

  validation {
    condition = alltrue([
      for k, v in var.vm_list : v.vm_memory > 0 && v.vm_memory <= 1048576
    ])
    error_message = "vm_memory должен быть положительным числом в МБ (максимум 1TB)"
  }

  validation {
    condition = alltrue([
      for k, v in var.vm_list : v.vm_disk_size > 0 && v.vm_disk_size <= 10000
    ])
    error_message = "vm_disk_size должен быть положительным числом в ГБ (максимум 10TB)"
  }

  validation {
    condition = alltrue([
      for k, v in var.vm_list : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", v.vm_ip))
    ])
    error_message = "vm_ip должен быть валидным IPv4 адресом"
  }

  validation {
    condition = alltrue([
      for k, v in var.vm_list : length(v.vm_hostname) > 0 && length(v.vm_hostname) <= 63
    ])
    error_message = "vm_hostname должен быть непустой строкой длиной до 63 символов"
  }

  validation {
    condition = alltrue([
      for k, v in var.vm_list : length(v.cloud_init_file) > 0
    ])
    error_message = "cloud_init_file не может быть пустым"
  }
}

variable "gateway_ip" {
  description = "IP-адрес шлюза для VM"
  type        = string

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.gateway_ip))
    error_message = "gateway_ip должен быть валидным IPv4 адресом"
  }
}

variable "iso_image" {
  description = "Путь к ISO образу в Proxmox datastore (например, local:iso/noble-server-cloudimg-amd64.img)"
  type        = string
  default     = null

  validation {
    condition     = var.iso_image == null || try(length(var.iso_image) > 0, false)
    error_message = "iso_image не может быть пустой строкой (используйте null для отключения)"
  }
}

variable "snippets_datastore_id" {
  description = "Хранилище для cloud-init snippets"
  type        = string
  default     = "local"

  validation {
    condition     = length(var.snippets_datastore_id) > 0
    error_message = "snippets_datastore_id не может быть пустым"
  }
}

variable "disk_datastore_id" {
  description = "Хранилище для дисков VM"
  type        = string

  validation {
    condition     = length(var.disk_datastore_id) > 0
    error_message = "disk_datastore_id не может быть пустым"
  }
}

variable "network_cidr" {
  description = "CIDR маска подсети для VM (например, 24 для /24)"
  type        = number
  default     = 24

  validation {
    condition     = var.network_cidr >= 0 && var.network_cidr <= 32
    error_message = "network_cidr должен быть числом от 0 до 32"
  }
}

variable "ansible_version" {
  description = "Версия Ansible для установки (используется только в ansible-control шаблоне)"
  type        = string
  default     = "12.3.0-1ppa~noble"

  validation {
    condition     = length(var.ansible_version) > 0
    error_message = "ansible_version не может быть пустым"
  }
}