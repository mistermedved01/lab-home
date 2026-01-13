# ============================================================================
# Proxmox Provider
# ============================================================================
# Конфигурация провайдера для работы с Proxmox VE API.
# 
# Параметры:
# - endpoint: URL API Proxmox (обычно https://<ip>:8006/)
# - api_token: API токен для аутентификации (создается в Proxmox)
# - insecure: разрешает самоподписанные сертификаты (для dev окружений)
#
# SSH конфигурация используется для некоторых операций провайдера.
# Поддерживает два режима:
# 1. SSH Agent (proxmox_use_ssh_agent = true) - более безопасно, удобно для CI/CD
# 2. Файл ключа (proxmox_ssh_key_path) - можно указать путь к ключу
# ============================================================================

# Локальные значения для вычисления пути к SSH ключу
locals {
  # Определяем путь к SSH ключу:
  # 1. Если указан proxmox_ssh_key_path - используем его (абсолютный или относительно live/)
  # 2. Иначе используем стандартный путь ~/.ssh/id_ed25519
  proxmox_ssh_key_path = var.proxmox_ssh_key_path != null ? (
    # Если путь начинается с / или ~, считаем его абсолютным
    startswith(var.proxmox_ssh_key_path, "/") || startswith(var.proxmox_ssh_key_path, "~") ?
    pathexpand(var.proxmox_ssh_key_path) :
    # Иначе считаем относительным от live/ директории
    "${path.root}/${var.proxmox_ssh_key_path}"
  ) : pathexpand("~/.ssh/id_ed25519")
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true

  ssh {
    # Используем SSH agent если включен, иначе используем файл ключа
    agent    = var.proxmox_use_ssh_agent
    username = "root"
    # private_key используется только если agent = false
    # Если agent = true, провайдер должен игнорировать private_key
    # Используем try() для безопасной обработки, если файл не найден при agent = true
    private_key = var.proxmox_use_ssh_agent ? try(file(local.proxmox_ssh_key_path), "") : file(local.proxmox_ssh_key_path)
  }
}