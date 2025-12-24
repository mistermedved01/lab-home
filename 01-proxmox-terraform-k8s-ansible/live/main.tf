module "vm-cloudinit" {
  source = "../modules/base-vm-cloudinit"

  proxmox_endpoint    = var.proxmox_endpoint
  proxmox_api_token   = var.proxmox_api_token
  node_name           = var.node_name
  datastore_id        = var.datastore_id
  network_bridge      = var.network_bridge
  ssh_authorized_keys = [var.ssh_public_key]
  vm_user             = var.vm_user
  ansible_version     = var.ansible_version

  vm_list               = var.vm_list
  gateway_ip            = var.gateway_ip
  template_vm_id        = var.template_vm_id
  snippets_datastore_id = var.snippets_datastore_id
  disk_datastore_id     = var.datastore_id
  network_cidr          = var.network_cidr
}

# Генерация файла inventory для Ansible
resource "local_file" "ansible_inventory" {
  filename = "${path.root}/ansible/inventory.yaml"

  content = templatefile(
    "${path.root}/templates/ansible_inventory.yaml.tftpl",
    {
      inventory = var.vm_list
      vm_user   = var.vm_user
    }
  )
}

# Получаем IP адрес ansible control VM из vm_list
locals {
  ansible_control_vm = var.vm_list[var.ansible_control_vm_key]
  ansible_host_ip    = local.ansible_control_vm.vm_ip
  ssh_key_full_path  = "${path.root}/${var.ansible_ssh_key_path}"
  ansible_ssh_user   = var.ansible_ssh_user != null ? var.ansible_ssh_user : var.vm_user
}

# Копируем inventory на ansible-control используя скрипт
resource "null_resource" "push_ansible_files" {
  depends_on = [module.vm-cloudinit, local_file.ansible_inventory]

  triggers = {
    inventory_content = local_file.ansible_inventory.content
    vm_ready          = join(",", keys(var.vm_list))
    ansible_host      = local.ansible_host_ip
    playbooks_dir     = sha256(join("", [for f in fileset("${path.root}/ansible/playbooks/playbooks", "**") : filesha256("${path.root}/ansible/playbooks/playbooks/${f}")]))
  }

  provisioner "local-exec" {
    command = <<-EOT
      chmod +x "${path.root}/scripts/push_ansible_files.sh" && \
      "${path.root}/scripts/push_ansible_files.sh" \
        "${local.ansible_host_ip}" \
        "${local.ansible_ssh_user}" \
        "${local.ssh_key_full_path}" \
        "${path.root}/ansible/inventory.yaml" \
        "${local.ssh_key_full_path}" \
        "${path.root}/ansible/playbooks"
    EOT

    interpreter = ["bash", "-c"]
  }
}
