variable "proxmox_nodes" {
  description = "Map узлов Proxmox: ключ — идентификатор ноды (например pve-node-01), значение — endpoint, api_token, node_name, datastore_id, network_bridge"
  type = map(object({
    endpoint       = string
    api_token      = string
    node_name      = string
    datastore_id   = optional(string, "local")
    network_bridge = optional(string, "vmbr0")
  }))

  validation {
    condition     = length(var.proxmox_nodes) > 0
    error_message = "proxmox_nodes должен содержать хотя бы один узел"
  }

  validation {
    condition = alltrue([
      for name, cfg in var.proxmox_nodes : can(regex("^https?://", cfg.endpoint))
    ])
    error_message = "endpoint каждого узла должен быть валидным URL (http:// или https://)"
  }

  validation {
    condition = alltrue([
      for name, cfg in var.proxmox_nodes : length(cfg.node_name) > 0
    ])
    error_message = "node_name не может быть пустым"
  }
}

variable "proxmox_ssh_key_path" {
  description = "Путь к приватному SSH ключу для подключения к Proxmox (для операций провайдера). Если не указан, используется ~/.ssh/id_ed25519. Можно использовать относительный путь от live/ директории (например, keys/id_ed25519) или абсолютный путь."
  type        = string
  default     = null

  validation {
    condition     = var.proxmox_ssh_key_path == null || length(var.proxmox_ssh_key_path) > 0
    error_message = "proxmox_ssh_key_path не может быть пустой строкой (используйте null для значения по умолчанию)"
  }
}

variable "proxmox_use_ssh_agent" {
  description = "Использовать SSH agent вместо файла ключа для подключения к Proxmox. Полезно для CI/CD или когда ключ уже загружен в SSH agent."
  type        = bool
  default     = false
}

variable "ssh_public_key" {
  description = "Публичный SSH-ключ для VM"
  type        = string

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|ssh-dss)", var.ssh_public_key))
    error_message = "ssh_public_key должен быть валидным публичным SSH ключом"
  }
}

variable "vm_list" {
  description = "Список VM для создания. Для каждой VM укажите proxmox_node — ключ из proxmox_nodes. vm_disk_size_extra — размер одного доп. диска в ГБ (20); 0 или не указывать — без доп. диска."
  type = map(object({
    vm_hostname        = string
    vm_ip              = string
    vm_id              = number
    vm_cores           = number
    vm_memory          = number
    vm_disk_size       = number
    cloud_init_file    = string
    role               = string
    proxmox_node       = string
    vm_disk_size_extra = optional(number, 0) # размер доп. диска в ГБ (20); 0 — без доп. диска
  }))

  validation {
    condition     = length(var.vm_list) > 0
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

  validation {
    condition = alltrue([
      for k, v in var.vm_list : v.vm_disk_size_extra >= 0 && v.vm_disk_size_extra <= 10000
    ])
    error_message = "vm_disk_size_extra должен быть от 0 до 10000 ГБ"
  }

  validation {
    condition = alltrue([
      for k, v in var.vm_list : contains(keys(var.proxmox_nodes), v.proxmox_node)
    ])
    error_message = "proxmox_node каждой VM должен быть ключом из proxmox_nodes"
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

variable "network_cidr" {
  description = "CIDR маска подсети для VM (например, 24 для /24)"
  type        = number
  default     = 24

  validation {
    condition     = var.network_cidr >= 0 && var.network_cidr <= 32
    error_message = "network_cidr должен быть числом от 0 до 32"
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

variable "ansible_control_vm_key" {
  description = "Ключ в vm_list для ansible control VM (используется для определения IP и имени)"
  type        = string
  default     = "ansible_control-01"

  validation {
    condition     = length(var.ansible_control_vm_key) > 0
    error_message = "ansible_control_vm_key не может быть пустым"
  }
}

variable "vm_user" {
  description = "Имя пользователя для создания на всех VM"
  type        = string
  default     = "ubuntu"

  validation {
    condition     = length(var.vm_user) > 0 && can(regex("^[a-z_][a-z0-9_-]*$", var.vm_user))
    error_message = "vm_user должен быть валидным именем пользователя Unix"
  }
}

variable "ansible_ssh_user" {
  description = "SSH пользователь для подключения к ansible control VM (обычно совпадает с vm_user)"
  type        = string
  default     = null

  validation {
    condition     = var.ansible_ssh_user == null || (var.ansible_ssh_user != "" && can(regex("^[a-z_][a-z0-9_-]*$", var.ansible_ssh_user)))
    error_message = "ansible_ssh_user должен быть валидным именем пользователя Unix или null (будет использован vm_user)"
  }
}

variable "ansible_ssh_key_path" {
  description = "Путь к приватному SSH ключу для подключения к ansible control VM"
  type        = string
  default     = "keys/id_ed25519"

  validation {
    condition     = length(var.ansible_ssh_key_path) > 0
    error_message = "ansible_ssh_key_path не может быть пустым"
  }
}

variable "ansible_version" {
  description = "Версия Ansible для установки на control VM. Укажите 'latest' для последней доступной версии из PPA."
  type        = string
  default     = "13.3.0-1ppa~noble"
  validation {
    condition     = length(var.ansible_version) > 0
    error_message = "ansible_version не может быть пустым"
  }
}

variable "skip_push_argocd_applications" {
  description = "Пропустить копирование 03-argocd на control plane (если нода ещё недоступна). После apply можно вручную: bash scripts/push_argocd_applications.sh <ip> ubuntu keys/id_ed25519 ../../../../03-argocd"
  type        = bool
  default     = false
}