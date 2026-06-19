variable "proxmox_nodes" {
  description = "Три ключа обязательны (как в vm-ubuntu): pve-node-01, pve-node-02, pve-node-03 — даже если CT создаёте только на одной ноде"
  type = map(object({
    endpoint       = string
    api_token      = string
    node_name      = string
    datastore_id   = optional(string, "local-lvm")
    network_bridge = optional(string, "vmbr0")
  }))

  validation {
    condition = alltrue([
      contains(keys(var.proxmox_nodes), "pve-node-01"),
      contains(keys(var.proxmox_nodes), "pve-node-02"),
      contains(keys(var.proxmox_nodes), "pve-node-03"),
    ])
    error_message = "В proxmox_nodes должны быть ключи pve-node-01, pve-node-02, pve-node-03"
  }
}

variable "proxmox_ssh_key_path" {
  type    = string
  default = null
}

variable "proxmox_use_ssh_agent" {
  type    = bool
  default = false
}

variable "ssh_public_key" {
  description = "Публичный SSH-ключ для root внутри CT"
  type        = string

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521)", var.ssh_public_key))
    error_message = "ssh_public_key должен начинаться с известного типа ключа"
  }
}

variable "gateway_ip" {
  description = "Шлюз IPv4 для CT"
  type        = string
}

variable "network_cidr_bits" {
  description = "Префикс подсети (24 для /24)"
  type        = number
  default     = 24
}

variable "dns_servers" {
  description = "DNS по умолчанию для всех CT (пусто — не задавать в cloud-init провайдера)"
  type        = list(string)
  default     = []
}

variable "lxc_list" {
  description = "Набор базовых LXC: ключ — произвольное имя ресурса в state"
  type = map(object({
    hostname             = string
    vm_id                = number
    ipv4_address         = string
    proxmox_node         = string
    template_file_id     = string
    os_type              = optional(string, "ubuntu")
    cpu_cores            = optional(number, 2)
    memory_mb            = optional(number, 2048)
    rootfs_gb            = optional(number, 16)
    unprivileged         = optional(bool, true)
    nesting              = optional(bool, false)
    fuse                 = optional(bool, false)
    keyctl               = optional(bool, false)
    description          = optional(string, null)
    network_interface    = optional(string, "eth0")
    dns_servers_override = optional(list(string), null)
    wait_for_ipv4        = optional(bool, null)
  }))

  validation {
    condition     = length(var.lxc_list) > 0
    error_message = "lxc_list не должен быть пустым"
  }

  validation {
    condition = alltrue([
      for k, v in var.lxc_list :
      contains(["pve-node-01", "pve-node-02", "pve-node-03"], v.proxmox_node)
    ])
    error_message = "proxmox_node каждого элемента должен быть pve-node-01, pve-node-02 или pve-node-03"
  }

  validation {
    condition = alltrue([
      for k, v in var.lxc_list : v.vm_id > 99 && v.vm_id < 1000000
    ])
    error_message = "vm_id должен быть в разумных пределах Proxmox"
  }
}
