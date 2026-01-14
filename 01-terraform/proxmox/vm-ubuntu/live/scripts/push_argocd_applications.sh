#!/bin/bash
#
# Скрипт для копирования ArgoCD Applications на control plane ноду
# Копирует директорию 03-argocd на Kubernetes control plane node
#
# Использование:
#   ./push_argocd_applications.sh <control_plane_host> <control_plane_user> <ssh_key_path> <applications_path>
#
# Параметры:
#   control_plane_host  - IP адрес или hostname control plane ноды
#   control_plane_user  - SSH пользователь для подключения
#   ssh_key_path        - Путь к приватному SSH ключу для подключения
#   applications_path   - Путь к директории с ArgoCD Applications

set -euo pipefail

# ============================================================================
# Конфигурация
# ============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly MAX_WAIT_ATTEMPTS=30

# Параметры скрипта
readonly CONTROL_PLANE_HOST="${1:-}"
readonly CONTROL_PLANE_USER="${2:-}"
readonly SSH_KEY_PATH="${3:-}"
readonly APPLICATIONS_PATH="${4:-}"

# ============================================================================
# Утилиты
# ============================================================================

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
      "$CONTROL_PLANE_USER@$CONTROL_PLANE_HOST" "$@"
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
  local resolved_path
  
  # Убираем ./ в начале пути
  path=$(echo "$path" | sed 's|^\./||')
  
  # Если путь абсолютный, проверяем его напрямую
  if [[ "$path" =~ ^/ ]]; then
    if [[ -d "$path" ]]; then
      cd "$path" && pwd
    else
      echo "$path"
    fi
    return
  fi
  
  # Если путь существует относительно текущей директории
  if [[ -d "$path" ]]; then
    cd "$path" && pwd
    return
  fi
  
  # Пробуем разрешить относительно директории скрипта
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  
  # Если путь начинается с ../, разрешаем его относительно директории скрипта
  if [[ "$path" =~ ^\.\./ ]]; then
    resolved_path="$(cd "$script_dir/$path" 2>/dev/null && pwd)"
    if [[ -n "$resolved_path" ]] && [[ -d "$resolved_path" ]]; then
      echo "$resolved_path"
      return
    fi
  fi
  
  # Пробуем найти относительно директории live (родительской для scripts)
  local terraform_live_dir="$(cd "$script_dir/.." && pwd)"
  resolved_path="$(cd "$terraform_live_dir/$path" 2>/dev/null && pwd)"
  if [[ -n "$resolved_path" ]] && [[ -d "$resolved_path" ]]; then
    echo "$resolved_path"
    return
  fi
  
  # Последняя попытка - разрешить как есть
  resolved_path="$(cd "$path" 2>/dev/null && pwd)"
  if [[ -n "$resolved_path" ]] && [[ -d "$resolved_path" ]]; then
    echo "$resolved_path"
    return
  fi
  
  log_warn "Путь не найден: $path"
  echo ""
}

# ============================================================================
# Валидация параметров
# ============================================================================

check_params() {
  local missing_params=()
  
  [[ -z "$CONTROL_PLANE_HOST" ]] && missing_params+=("control_plane_host")
  [[ -z "$CONTROL_PLANE_USER" ]] && missing_params+=("control_plane_user")
  [[ -z "$SSH_KEY_PATH" ]] && missing_params+=("ssh_key_path")
  [[ -z "$APPLICATIONS_PATH" ]] && missing_params+=("applications_path")
  
  if [[ ${#missing_params[@]} -gt 0 ]]; then
    error_exit "Не указаны обязательные параметры: ${missing_params[*]}"
  fi
  
  if [[ ! -f "$SSH_KEY_PATH" ]]; then
    error_exit "SSH ключ не найден: $SSH_KEY_PATH"
  fi
  
  # Нормализуем путь к Applications
  local apps_abs_path
  apps_abs_path=$(normalize_path "$APPLICATIONS_PATH")
  
  if [[ -z "$apps_abs_path" ]] || [[ ! -d "$apps_abs_path" ]]; then
    error_exit "Директория Applications не найдена: $APPLICATIONS_PATH (проверено: $apps_abs_path)"
  fi
}

# ============================================================================
# Ожидание доступности хоста
# ============================================================================

wait_for_host() {
  log_info "Проверка доступности $CONTROL_PLANE_HOST..."
  
  for i in $(seq 1 $MAX_WAIT_ATTEMPTS); do
    if ssh_cmd "echo 'Host is ready'" >/dev/null 2>&1; then
      log_info "Хост доступен"
      return 0
    fi
    
    if [[ $i -eq $MAX_WAIT_ATTEMPTS ]]; then
      error_exit "Хост $CONTROL_PLANE_HOST недоступен после $MAX_WAIT_ATTEMPTS попыток"
    fi
    
    log_info "Ожидание доступности хоста... ($i/$MAX_WAIT_ATTEMPTS)"
    sleep 2
  done
}

# ============================================================================
# Копирование файлов
# ============================================================================

copy_applications() {
  # Нормализуем путь к Applications
  local apps_abs_path
  apps_abs_path=$(normalize_path "$APPLICATIONS_PATH")
  
  if [[ -z "$apps_abs_path" ]] || [[ ! -d "$apps_abs_path" ]]; then
    error_exit "Директория Applications не найдена: $APPLICATIONS_PATH"
  fi
  
  log_info "Копирование ArgoCD Applications из $apps_abs_path..."
  
  # Создание директории на control plane ноде
  ssh_cmd "mkdir -p /home/$CONTROL_PLANE_USER/03-argocd"
  
  # Копирование всех файлов
  if ! scp_cmd -r "$apps_abs_path/"* "$CONTROL_PLANE_USER@$CONTROL_PLANE_HOST:/home/$CONTROL_PLANE_USER/03-argocd/"; then
    error_exit "Не удалось скопировать Applications"
  fi
  
  # Настройка прав
  ssh_cmd "chown -R $CONTROL_PLANE_USER:$CONTROL_PLANE_USER /home/$CONTROL_PLANE_USER/03-argocd && \
           chmod -R 755 /home/$CONTROL_PLANE_USER/03-argocd"
  
  # Проверка успешного копирования
  if ! ssh_cmd "test -d /home/$CONTROL_PLANE_USER/03-argocd"; then
    error_exit "Applications не найдены после копирования"
  fi
  
  log_info "Applications успешно скопированы на control plane ноду"
}

# ============================================================================
# Главная функция
# ============================================================================

main() {
  log_info "Запуск скрипта $SCRIPT_NAME"
  
  check_params
  wait_for_host
  copy_applications
  
  log_info "Все файлы успешно скопированы на control plane ноду"
}

# Запуск
main "$@"

