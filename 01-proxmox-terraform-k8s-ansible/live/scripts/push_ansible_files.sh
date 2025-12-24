#!/bin/bash
# Скрипт для копирования файлов Ansible на control VM
# Использование: ./push_ansible_files.sh <ansible_host> <ansible_user> <ssh_key_path> <inventory_path> <private_key_path> <playbooks_path>

set -e

# Параметры скрипта
ANSIBLE_HOST="${1}"
ANSIBLE_USER="${2}"
SSH_KEY_PATH="${3}"
INVENTORY_PATH="${4}"
PRIVATE_KEY_PATH="${5}"
PLAYBOOKS_PATH="${6}"

# Константы
MAX_WAIT_ATTEMPTS=30
MAX_ANSIBLE_WAIT_ATTEMPTS=60
ANSIBLE_WAIT_DELAY=5
ANSIBLE_FINAL_DELAY=15

# Функции для SSH/SCP
ssh_cmd() {
  ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$ANSIBLE_USER@$ANSIBLE_HOST" "$@"
}

scp_cmd() {
  scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$@"
}

# Функции
error_exit() {
  echo "ОШИБКА: $1" >&2
  exit 1
}

check_params() {
  if [ -z "$ANSIBLE_HOST" ] || [ -z "$ANSIBLE_USER" ] || [ -z "$SSH_KEY_PATH" ]; then
    error_exit "не указаны обязательные параметры"
  fi
}

wait_for_host() {
  echo "Проверка доступности $ANSIBLE_HOST..."
  for i in $(seq 1 $MAX_WAIT_ATTEMPTS); do
    if ssh_cmd "echo 'Host is ready'" 2>/dev/null; then
      echo "Хост доступен"
      return 0
    fi
    if [ $i -eq $MAX_WAIT_ATTEMPTS ]; then
      error_exit "хост $ANSIBLE_HOST недоступен после $MAX_WAIT_ATTEMPTS попыток"
    fi
    echo "Ожидание доступности хоста... ($i/$MAX_WAIT_ATTEMPTS)"
    sleep 2
  done
}

copy_inventory() {
  echo "Копирование inventory.yaml..."
  if ! scp_cmd "$INVENTORY_PATH" "$ANSIBLE_USER@$ANSIBLE_HOST:/home/$ANSIBLE_USER/inventory.yaml"; then
    error_exit "не удалось скопировать inventory.yaml"
  fi

  echo "Проверка скопированного файла..."
  if ! ssh_cmd "test -f /home/$ANSIBLE_USER/inventory.yaml"; then
    error_exit "inventory.yaml не найден после копирования"
  fi
  echo "inventory.yaml успешно скопирован"
}

copy_ssh_key() {
  echo "Копирование приватного ключа..."
  ssh_cmd "mkdir -p /home/$ANSIBLE_USER/.ssh"
  scp_cmd "$PRIVATE_KEY_PATH" "$ANSIBLE_USER@$ANSIBLE_HOST:/home/$ANSIBLE_USER/.ssh/id_ed25519"
}

copy_playbooks() {
  if [ -z "$PLAYBOOKS_PATH" ]; then
    echo "Предупреждение: путь к playbooks не указан"
    return 0
  fi

  echo "Проверка пути к playbooks: $PLAYBOOKS_PATH"
  if [ ! -d "$PLAYBOOKS_PATH" ]; then
    echo "Предупреждение: путь к playbooks не существует: $PLAYBOOKS_PATH"
    return 0
  fi

  echo "Директория найдена, копирование playbooks..."
  ssh_cmd "mkdir -p /home/$ANSIBLE_USER/playbooks"
  
  if [ -d "$PLAYBOOKS_PATH/playbooks" ]; then
    echo "Копирование playbooks из $PLAYBOOKS_PATH/playbooks..."
    scp_cmd -r "$PLAYBOOKS_PATH/playbooks/"* "$ANSIBLE_USER@$ANSIBLE_HOST:/home/$ANSIBLE_USER/playbooks/"
  else
    echo "Предупреждение: директория $PLAYBOOKS_PATH/playbooks не найдена"
  fi
  
  if [ -d "$PLAYBOOKS_PATH/group_vars" ]; then
    echo "Копирование group_vars..."
    scp_cmd -r "$PLAYBOOKS_PATH/group_vars" "$ANSIBLE_USER@$ANSIBLE_HOST:/home/$ANSIBLE_USER/playbooks/"
  else
    echo "Предупреждение: директория $PLAYBOOKS_PATH/group_vars не найдена"
  fi
}

wait_for_ansible() {
  echo "Ожидание завершения установки Ansible..."
  for i in $(seq 1 $MAX_ANSIBLE_WAIT_ATTEMPTS); do
    if ssh_cmd "command -v ansible >/dev/null 2>&1"; then
      echo "Ansible установлен, ожидание завершения всех процессов установки..."
      sleep $ANSIBLE_FINAL_DELAY
      return 0
    fi
    if [ $i -eq $MAX_ANSIBLE_WAIT_ATTEMPTS ]; then
      echo "Предупреждение: Ansible не установлен после $MAX_ANSIBLE_WAIT_ATTEMPTS попыток, продолжаем..."
    fi
    sleep $ANSIBLE_WAIT_DELAY
  done
}

setup_remote_host() {
  echo "Настройка на удаленном хосте..."
  
  # Используем один heredoc и создаем ansible.cfg через echo
  ssh_cmd << EOF
set -e

sudo mkdir -p /etc/ansible

sleep 60
# Создаем ansible.cfg с помощью echo вместо вложенного heredoc
echo "[defaults]
inventory = /etc/ansible/inventory.yaml
host_key_checking = False" | sudo tee /etc/ansible/ansible.cfg > /dev/null

sudo chmod 644 /etc/ansible/ansible.cfg

# Копируем inventory.yaml
if [ -f /home/$ANSIBLE_USER/inventory.yaml ]; then
  sudo cp -f /home/$ANSIBLE_USER/inventory.yaml /etc/ansible/inventory.yaml
  sudo chown root:root /etc/ansible/inventory.yaml
  sudo chmod 644 /etc/ansible/inventory.yaml
  echo "inventory.yaml скопирован в /etc/ansible/"
fi

# Проверяем и настраиваем права на SSH ключ
if [ -f /home/$ANSIBLE_USER/.ssh/id_ed25519 ]; then
  chmod 600 /home/$ANSIBLE_USER/.ssh/id_ed25519
  chown $ANSIBLE_USER:$ANSIBLE_USER /home/$ANSIBLE_USER/.ssh/id_ed25519
  echo "SSH ключ настроен"
else
  echo "Предупреждение: SSH ключ не найден в /home/$ANSIBLE_USER/.ssh/id_ed25519"
fi

# Перемещаем playbooks в /etc/ansible/
if [ -d /home/$ANSIBLE_USER/playbooks ]; then
  sudo rm -rf /etc/ansible/playbooks
  sudo mv /home/$ANSIBLE_USER/playbooks /etc/ansible/playbooks
  sudo chown -R root:root /etc/ansible/playbooks
  sudo chmod -R 755 /etc/ansible/playbooks
  echo "playbooks скопированы в /etc/ansible/playbooks/"
fi

echo "Настройка завершена успешно"
EOF

  if [ $? -ne 0 ]; then
    error_exit "настройка на удаленном хосте завершилась с ошибкой"
  fi
}

# Главная функция
main() {
  check_params
  wait_for_host
  copy_inventory
  copy_ssh_key
  copy_playbooks
  wait_for_ansible
  setup_remote_host
  echo "Файлы успешно скопированы и настроены"
}

# Запуск
main