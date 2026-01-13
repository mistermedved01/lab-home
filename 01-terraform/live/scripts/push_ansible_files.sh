#!/bin/bash
#
# Скрипт для копирования файлов Ansible на control VM
# Автоматически копирует inventory, playbooks, roles и helm values на Ansible control node
#
# Использование:
#   ./push_ansible_files.sh <ansible_host> <ansible_user> <ssh_key_path> \
#                           <inventory_path> <private_key_path> <playbooks_path>
#
# Параметры:
#   ansible_host      - IP адрес или hostname Ansible control VM
#   ansible_user      - SSH пользователь для подключения
#   ssh_key_path      - Путь к приватному SSH ключу для подключения
#   inventory_path    - Путь к файлу inventory (hosts.yaml)
#   private_key_path  - Путь к приватному SSH ключу для копирования на VM
#   playbooks_path    - Путь к директории с Ansible playbooks и roles (включая Helm values)
#

set -euo pipefail

# ============================================================================
# Конфигурация
# ============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly MAX_WAIT_ATTEMPTS=30
readonly MAX_ANSIBLE_WAIT_ATTEMPTS=60
readonly ANSIBLE_WAIT_DELAY=5
readonly ANSIBLE_FINAL_DELAY=15
readonly REMOTE_ANSIBLE_DIR="/etc/ansible"
readonly REMOTE_HOME_DIR="/home"

# Параметры скрипта
readonly ANSIBLE_HOST="${1:-}"
readonly ANSIBLE_USER="${2:-}"
readonly SSH_KEY_PATH="${3:-}"
readonly INVENTORY_PATH="${4:-}"
readonly PRIVATE_KEY_PATH="${5:-}"
readonly PLAYBOOKS_PATH="${6:-}"

# ============================================================================
# Утилиты
# ============================================================================

# Логирование
log_info() {
  echo "[INFO] $*"
}

log_warn() {
  echo "[WARN] $*" >&2
}

log_error() {
  echo "[ERROR] $*" >&2
}

error_exit() {
  log_error "$1"
  exit 1
}

# SSH/SCP команды с общими опциями
ssh_cmd() {
  ssh -i "$SSH_KEY_PATH" \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      "$ANSIBLE_USER@$ANSIBLE_HOST" "$@"
}

scp_cmd() {
  scp -i "$SSH_KEY_PATH" \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      "$@"
}

# Преобразование пути в абсолютный
normalize_path() {
  local path="$1"
  local script_dir
  
  # Убираем ./ в начале пути
  path=$(echo "$path" | sed 's|^\./||')
  
  # Если путь абсолютный или существует, возвращаем его
  if [[ "$path" =~ ^/ ]] || [[ -d "$path" ]]; then
    if [[ -d "$path" ]]; then
      cd "$path" && pwd
    else
      echo "$path"
    fi
  else
    # Пробуем найти относительно директории скрипта
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local terraform_live_dir="$(cd "$script_dir/.." && pwd)"
    local alt_path="$terraform_live_dir/$path"
    
    if [[ -d "$alt_path" ]]; then
      cd "$alt_path" && pwd
    else
      log_warn "Путь не найден: $path"
      echo ""
    fi
  fi
}

# ============================================================================
# Валидация параметров
# ============================================================================

check_params() {
  local missing_params=()
  
  [[ -z "$ANSIBLE_HOST" ]] && missing_params+=("ansible_host")
  [[ -z "$ANSIBLE_USER" ]] && missing_params+=("ansible_user")
  [[ -z "$SSH_KEY_PATH" ]] && missing_params+=("ssh_key_path")
  
  if [[ ${#missing_params[@]} -gt 0 ]]; then
    error_exit "Не указаны обязательные параметры: ${missing_params[*]}"
  fi
  
  if [[ ! -f "$SSH_KEY_PATH" ]]; then
    error_exit "SSH ключ не найден: $SSH_KEY_PATH"
  fi
  
  # Проверяем права на SSH ключ
  local key_perms
  key_perms=$(stat -c "%a" "$SSH_KEY_PATH" 2>/dev/null || stat -f "%OLp" "$SSH_KEY_PATH" 2>/dev/null || echo "000")
  if [[ "$key_perms" != "600" ]] && [[ "$key_perms" != "400" ]]; then
    log_warn "Рекомендуется установить права 600 на SSH ключ: chmod 600 $SSH_KEY_PATH"
  fi
}

# ============================================================================
# Ожидание доступности хоста
# ============================================================================

wait_for_host() {
  log_info "Проверка доступности $ANSIBLE_HOST..."
  
  for i in $(seq 1 $MAX_WAIT_ATTEMPTS); do
    if ssh_cmd "echo 'Host is ready'" >/dev/null 2>&1; then
      log_info "Хост доступен"
      return 0
    fi
    
    if [[ $i -eq $MAX_WAIT_ATTEMPTS ]]; then
      error_exit "Хост $ANSIBLE_HOST недоступен после $MAX_WAIT_ATTEMPTS попыток"
    fi
    
    log_info "Ожидание доступности хоста... ($i/$MAX_WAIT_ATTEMPTS)"
    sleep 2
  done
}

# ============================================================================
# Копирование файлов
# ============================================================================

copy_inventory() {
  if [[ -z "$INVENTORY_PATH" ]] || [[ ! -f "$INVENTORY_PATH" ]]; then
    log_warn "Inventory файл не указан или не найден, пропускаем"
    return 0
  fi
  
  log_info "Копирование inventory (hosts.yaml)..."
  ssh_cmd "mkdir -p $REMOTE_HOME_DIR/$ANSIBLE_USER/inventory/prod"
  
  if ! scp_cmd "$INVENTORY_PATH" "$ANSIBLE_USER@$ANSIBLE_HOST:$REMOTE_HOME_DIR/$ANSIBLE_USER/inventory/prod/hosts.yaml"; then
    error_exit "Не удалось скопировать inventory"
  fi
  
  # Проверка успешного копирования
  if ! ssh_cmd "test -f $REMOTE_HOME_DIR/$ANSIBLE_USER/inventory/prod/hosts.yaml"; then
    error_exit "inventory/prod/hosts.yaml не найден после копирования"
  fi
  
  log_info "Inventory успешно скопирован"
}

copy_ssh_key() {
  if [[ -z "$PRIVATE_KEY_PATH" ]] || [[ ! -f "$PRIVATE_KEY_PATH" ]]; then
    log_warn "Приватный SSH ключ не указан или не найден, пропускаем"
    return 0
  fi
  
  log_info "Копирование приватного SSH ключа..."
  ssh_cmd "mkdir -p $REMOTE_HOME_DIR/$ANSIBLE_USER/.ssh"
  scp_cmd "$PRIVATE_KEY_PATH" "$ANSIBLE_USER@$ANSIBLE_HOST:$REMOTE_HOME_DIR/$ANSIBLE_USER/.ssh/id_ed25519"
  
  # Настройка прав на ключ
  ssh_cmd "chmod 600 $REMOTE_HOME_DIR/$ANSIBLE_USER/.ssh/id_ed25519 && \
           chown $ANSIBLE_USER:$ANSIBLE_USER $REMOTE_HOME_DIR/$ANSIBLE_USER/.ssh/id_ed25519"
  
  log_info "SSH ключ скопирован и настроен"
}

copy_ansible_files() {
  if [[ -z "$PLAYBOOKS_PATH" ]]; then
    log_warn "Путь к Ansible не указан, пропускаем копирование playbooks"
    return 0
  fi
  
  local ansible_abs_path
  ansible_abs_path=$(normalize_path "$PLAYBOOKS_PATH")
  
  if [[ -z "$ansible_abs_path" ]] || [[ ! -d "$ansible_abs_path" ]]; then
    log_warn "Директория Ansible не найдена: $PLAYBOOKS_PATH"
    return 0
  fi
  
  log_info "Копирование Ansible файлов из $ansible_abs_path..."
  
  # Копирование playbooks
  if [[ -d "$ansible_abs_path/playbooks" ]]; then
    log_info "Копирование playbooks..."
    ssh_cmd "mkdir -p $REMOTE_HOME_DIR/$ANSIBLE_USER/playbooks"
    scp_cmd -r "$ansible_abs_path/playbooks/"* "$ANSIBLE_USER@$ANSIBLE_HOST:$REMOTE_HOME_DIR/$ANSIBLE_USER/playbooks/"
  fi
  
  # Копирование roles
  if [[ -d "$ansible_abs_path/roles" ]]; then
    log_info "Копирование roles..."
    ssh_cmd "mkdir -p $REMOTE_HOME_DIR/$ANSIBLE_USER/roles"
    scp_cmd -r "$ansible_abs_path/roles/"* "$ANSIBLE_USER@$ANSIBLE_HOST:$REMOTE_HOME_DIR/$ANSIBLE_USER/roles/"
  fi
  
  # Копирование group_vars
  if [[ -d "$ansible_abs_path/inventory/prod/group_vars" ]]; then
    log_info "Копирование group_vars..."
    ssh_cmd "mkdir -p $REMOTE_HOME_DIR/$ANSIBLE_USER/inventory/prod/group_vars"
    scp_cmd -r "$ansible_abs_path/inventory/prod/group_vars/"* \
              "$ANSIBLE_USER@$ANSIBLE_HOST:$REMOTE_HOME_DIR/$ANSIBLE_USER/inventory/prod/group_vars/"
  fi
  
  # Копирование конфигурационных файлов
  if [[ -f "$ansible_abs_path/ansible.cfg" ]]; then
    log_info "Копирование ansible.cfg..."
    scp_cmd "$ansible_abs_path/ansible.cfg" "$ANSIBLE_USER@$ANSIBLE_HOST:$REMOTE_HOME_DIR/$ANSIBLE_USER/ansible.cfg"
  fi
  
  log_info "Ansible файлы скопированы"
}



# ============================================================================
# Ожидание установки Ansible
# ============================================================================

wait_for_ansible() {
  log_info "Ожидание завершения установки Ansible..."
  
  for i in $(seq 1 $MAX_ANSIBLE_WAIT_ATTEMPTS); do
    if ssh_cmd "command -v ansible >/dev/null 2>&1"; then
      log_info "Ansible установлен, ожидание завершения всех процессов установки..."
      sleep $ANSIBLE_FINAL_DELAY
      return 0
    fi
    
    if [[ $i -eq $MAX_ANSIBLE_WAIT_ATTEMPTS ]]; then
      log_warn "Ansible не установлен после $MAX_ANSIBLE_WAIT_ATTEMPTS попыток, продолжаем..."
      return 0
    fi
    
    sleep $ANSIBLE_WAIT_DELAY
  done
}

# ============================================================================
# Настройка удаленного хоста
# ============================================================================

setup_remote_host() {
  log_info "Настройка на удаленном хосте..."
  
  ssh_cmd "ANSIBLE_USER='$ANSIBLE_USER' bash" <<'REMOTE_SCRIPT'
set -euo pipefail

REMOTE_ANSIBLE_DIR="/etc/ansible"
REMOTE_HOME_DIR="/home"

# Создание структуры директорий
sudo mkdir -p "$REMOTE_ANSIBLE_DIR/inventory/prod/group_vars"

# Ожидание завершения cloud-init
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }

log_info "Ожидание завершения cloud-init..."
sleep 60

# Настройка ansible.cfg
if [[ -f "$REMOTE_HOME_DIR/$ANSIBLE_USER/ansible.cfg" ]]; then
  log_info "Адаптация ansible.cfg для удаленного хоста..."
  sudo cp -f "$REMOTE_HOME_DIR/$ANSIBLE_USER/ansible.cfg" "$REMOTE_ANSIBLE_DIR/ansible.cfg.tmp"
  sudo sed -i 's|inventory = inventory/prod/hosts.yaml|inventory = /etc/ansible/inventory/prod/hosts.yaml|g' "$REMOTE_ANSIBLE_DIR/ansible.cfg.tmp"
  sudo sed -i 's|roles_path = roles|roles_path = /etc/ansible/roles|g' "$REMOTE_ANSIBLE_DIR/ansible.cfg.tmp"
  sudo mv "$REMOTE_ANSIBLE_DIR/ansible.cfg.tmp" "$REMOTE_ANSIBLE_DIR/ansible.cfg"
  sudo chown root:root "$REMOTE_ANSIBLE_DIR/ansible.cfg"
  sudo chmod 644 "$REMOTE_ANSIBLE_DIR/ansible.cfg"
else
  log_info "Создание ansible.cfg..."
  sudo tee "$REMOTE_ANSIBLE_DIR/ansible.cfg" > /dev/null <<EOF
[defaults]
inventory = $REMOTE_ANSIBLE_DIR/inventory/prod/hosts.yaml
host_key_checking = False
roles_path = $REMOTE_ANSIBLE_DIR/roles
EOF
  sudo chmod 644 "$REMOTE_ANSIBLE_DIR/ansible.cfg"
fi

# Копирование inventory
if [[ -f "$REMOTE_HOME_DIR/$ANSIBLE_USER/inventory/prod/hosts.yaml" ]]; then
  log_info "Копирование inventory..."
  sudo cp -f "$REMOTE_HOME_DIR/$ANSIBLE_USER/inventory/prod/hosts.yaml" \
             "$REMOTE_ANSIBLE_DIR/inventory/prod/hosts.yaml"
  sudo chown root:root "$REMOTE_ANSIBLE_DIR/inventory/prod/hosts.yaml"
  sudo chmod 644 "$REMOTE_ANSIBLE_DIR/inventory/prod/hosts.yaml"
fi

# Копирование group_vars
if [[ -d "$REMOTE_HOME_DIR/$ANSIBLE_USER/inventory/prod/group_vars" ]]; then
  log_info "Копирование group_vars..."
  sudo cp -rf "$REMOTE_HOME_DIR/$ANSIBLE_USER/inventory/prod/group_vars/"* \
              "$REMOTE_ANSIBLE_DIR/inventory/prod/group_vars/"
  sudo chown -R root:root "$REMOTE_ANSIBLE_DIR/inventory/prod/group_vars"
  sudo chmod -R 644 "$REMOTE_ANSIBLE_DIR/inventory/prod/group_vars"/*
fi

# Перемещение playbooks
if [[ -d "$REMOTE_HOME_DIR/$ANSIBLE_USER/playbooks" ]]; then
  log_info "Перемещение playbooks в $REMOTE_ANSIBLE_DIR/playbooks..."
  sudo rm -rf "$REMOTE_ANSIBLE_DIR/playbooks"
  sudo mv "$REMOTE_HOME_DIR/$ANSIBLE_USER/playbooks" "$REMOTE_ANSIBLE_DIR/playbooks"
  sudo chown -R root:root "$REMOTE_ANSIBLE_DIR/playbooks"
  sudo chmod -R 755 "$REMOTE_ANSIBLE_DIR/playbooks"
fi

# Перемещение roles
if [[ -d "$REMOTE_HOME_DIR/$ANSIBLE_USER/roles" ]]; then
  log_info "Перемещение roles в $REMOTE_ANSIBLE_DIR/roles..."
  sudo rm -rf "$REMOTE_ANSIBLE_DIR/roles"
  sudo mv "$REMOTE_HOME_DIR/$ANSIBLE_USER/roles" "$REMOTE_ANSIBLE_DIR/roles"
  sudo chown -R root:root "$REMOTE_ANSIBLE_DIR/roles"
  sudo chmod -R 755 "$REMOTE_ANSIBLE_DIR/roles"
fi

log_info "Настройка завершена успешно"
REMOTE_SCRIPT

  if [[ $? -ne 0 ]]; then
    error_exit "Настройка на удаленном хосте завершилась с ошибкой"
  fi
}

# ============================================================================
# Главная функция
# ============================================================================

main() {
  log_info "Запуск скрипта $SCRIPT_NAME"
  
  check_params
  wait_for_host
  copy_inventory
  copy_ssh_key
  copy_ansible_files
  wait_for_ansible
  setup_remote_host
  
  log_info "Все файлы успешно скопированы и настроены"
}

# Запуск
main "$@"
