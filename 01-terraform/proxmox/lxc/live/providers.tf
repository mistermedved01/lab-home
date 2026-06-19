# Те же alias, что в vm-ubuntu/live, чтобы переиспользовать токен и endpoint нод кластера.

locals {
  proxmox_ssh_key_path = var.proxmox_ssh_key_path != null ? (
    startswith(var.proxmox_ssh_key_path, "/") || startswith(var.proxmox_ssh_key_path, "~") ?
    pathexpand(var.proxmox_ssh_key_path) :
    "${path.root}/${var.proxmox_ssh_key_path}"
  ) : pathexpand("~/.ssh/id_ed25519")
}

provider "proxmox" {
  alias     = "pve_node_01"
  endpoint  = var.proxmox_nodes["pve-node-01"].endpoint
  api_token = var.proxmox_nodes["pve-node-01"].api_token
  insecure  = true

  ssh {
    agent       = var.proxmox_use_ssh_agent
    username    = "root"
    private_key = var.proxmox_use_ssh_agent ? try(file(local.proxmox_ssh_key_path), "") : file(local.proxmox_ssh_key_path)
  }
}

provider "proxmox" {
  alias     = "pve_node_02"
  endpoint  = var.proxmox_nodes["pve-node-02"].endpoint
  api_token = var.proxmox_nodes["pve-node-02"].api_token
  insecure  = true

  ssh {
    agent       = var.proxmox_use_ssh_agent
    username    = "root"
    private_key = var.proxmox_use_ssh_agent ? try(file(local.proxmox_ssh_key_path), "") : file(local.proxmox_ssh_key_path)
  }
}

provider "proxmox" {
  alias     = "pve_node_03"
  endpoint  = var.proxmox_nodes["pve-node-03"].endpoint
  api_token = var.proxmox_nodes["pve-node-03"].api_token
  insecure  = true

  ssh {
    agent       = var.proxmox_use_ssh_agent
    username    = "root"
    private_key = var.proxmox_use_ssh_agent ? try(file(local.proxmox_ssh_key_path), "") : file(local.proxmox_ssh_key_path)
  }
}
