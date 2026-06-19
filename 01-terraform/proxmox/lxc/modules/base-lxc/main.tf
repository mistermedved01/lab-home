resource "proxmox_virtual_environment_container" "this" {
  description = var.description

  node_name = var.node_name
  vm_id     = var.vm_id

  unprivileged = var.unprivileged

  features {
    nesting = var.nesting
    fuse    = var.fuse
    keyctl  = var.keyctl
  }

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = "${var.ipv4_address}/${var.network_cidr_bits}"
        gateway = var.ipv4_gateway
      }
    }

    dynamic "dns" {
      for_each = length(var.dns_servers) > 0 ? [1] : []
      content {
        servers = var.dns_servers
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.rootfs_gb
  }

  network_interface {
    name   = var.network_interface_name
    bridge = var.bridge
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = var.os_type
  }

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory_mb
  }

  console {
    type = "tty"
  }

  dynamic "wait_for_ip" {
    for_each = var.wait_for_ipv4 ? [1] : []
    content {
      ipv4 = true
    }
  }
}
