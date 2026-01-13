# Terraform Infrastructure

Этот каталог содержит Terraform конфигурацию для развертывания виртуальных машин в Proxmox и автоматической настройки инфраструктуры Kubernetes с помощью Ansible.

<details>
<summary><strong>📋Описание</strong></summary>

---

Terraform конфигурация автоматизирует:

- **Создание виртуальных машин** в Proxmox VE
- **Настройку cloud-init** для начальной конфигурации VM
- **Генерацию Ansible inventory** на основе созданных VM
- **Копирование файлов** на Ansible control VM и Kubernetes control plane
- **Интеграцию с Ansible** для дальнейшего развертывания Kubernetes кластера

Проект использует модульную структуру для переиспользования конфигураций и следует best practices Terraform.

</details>

<details>
<summary><strong>📋Структура</strong></summary>

---

```
01-terraform/
├── live/                    # Environment-specific конфигурация
│   ├── main.tf             # Основная конфигурация
│   ├── variables.tf        # Определение переменных
│   ├── providers.tf        # Конфигурация провайдеров
│   ├── versions.tf         # Версии провайдеров
│   ├── outputs.tf          # Outputs конфигурации
│   ├── terraform.tfvars    # Значения переменных (не коммитится)
│   ├── terraform.tfvars.example  # Пример конфигурации
│   ├── backend.tf.example # Конфигурация remote backend (опционально)
│   ├── keys/               # SSH ключи (не коммитятся)
│   │   ├── id_ed25519      # Приватный ключ
│   │   └── id_ed25519.pub  # Публичный ключ
│   ├── scripts/            # Вспомогательные скрипты
│   │   ├── push_ansible_files.sh      # Копирование Ansible файлов
│   │   └── push_argocd_applications.sh # Копирование ArgoCD Applications
│   └── templates/          # Terraform шаблоны
│       └── ansible_inventory.yaml.tftpl  # Шаблон Ansible inventory
└── modules/                # Переиспользуемые модули
    └── base-vm-cloudinit/  # Модуль создания VM с cloud-init
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        ├── versions.tf
        └── cloud-init/      # Cloud-init шаблоны
            ├── ansible-control.yaml.tftpl
            ├── k8s-control.yaml.tftpl
            └── k8s-worker.yaml.tftpl
```

</details>

<details>
<summary><strong>🚀Быстрый старт</strong></summary>

---

### Предварительные требования

- **Terraform** >= 1.0
- **Proxmox VE** с настроенным API доступом
- **SSH ключ** для доступа к создаваемым VM
- **Bash** (для скриптов)

### Подготовка

1. **Скопируйте пример конфигурации:**
   ```bash
   cd live
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Отредактируйте `terraform.tfvars`** и заполните реальные значения:
   - `proxmox_endpoint` - URL вашего Proxmox API
   - `proxmox_api_token` - API токен для Terraform
   - `ssh_public_key` - ваш публичный SSH ключ
   - `vm_list` - список виртуальных машин для создания

3. **Создайте API токен в Proxmox:**
   ```bash
   # В Proxmox веб-интерфейсе или через CLI:
   pveum user token add terraform@pve terraform-token --privsep 0
   ```

4. **Подготовьте SSH ключи:**
   ```bash
   # Если ключей нет, создайте их:
   ssh-keygen -t ed25519 -f keys/id_ed25519 -N ""
   chmod 600 keys/id_ed25519
   chmod 644 keys/id_ed25519.pub
   ```

### Инициализация и применение

```bash
cd live

# Инициализация
terraform init

# Планирование (просмотр изменений)
terraform plan

# Применение
terraform apply
```

Terraform автоматически:
- Создаст виртуальные машины в Proxmox
- Настроит cloud-init конфигурации
- Сгенерирует Ansible inventory файл
- Скопирует файлы на Ansible control VM и Kubernetes control plane

</details>

<details>
<summary><strong>⚙️Переменные</strong></summary>

---

### Основные переменные

| Переменная | Описание | Обязательная | По умолчанию |
|------------|----------|--------------|--------------|
| `proxmox_endpoint` | URL API Proxmox | Да | - |
| `proxmox_api_token` | API токен | Да | - |
| `node_name` | Имя узла Proxmox | Нет | `pve-node-01` |
| `datastore_id` | Хранилище для дисков | Нет | `local-lvm` |
| `network_bridge` | Сетевой мост | Нет | `vmbr0` |
| `gateway_ip` | IP шлюза | Да | - |
| `template_vm_id` | ID шаблона VM | Нет | `9000` |
| `ssh_public_key` | Публичный SSH ключ | Да | - |
| `vm_list` | Список VM для создания | Да | - |

Полный список переменных см. в `live/variables.tf`.

### Использование переменных окружения

Для безопасности можно использовать переменные окружения вместо `terraform.tfvars`:

```bash
export TF_VAR_proxmox_api_token="terraform@pve!terraform-token=YOUR_TOKEN"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
terraform apply
```

### Пример конфигурации

```hcl
# terraform.tfvars
proxmox_endpoint = "https://pve.example.com:8006/api2/json"
proxmox_api_token = "terraform@pve!terraform-token=YOUR_TOKEN"

gateway_ip = "192.168.1.1"
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... user@host"

vm_list = {
  "ansible-control-01" = {
    ipv4 = "192.168.1.10"
    cores = 2
    memory = 4096
    disk_size = 20
  }
  "k8s-control-01" = {
    ipv4 = "192.168.1.20"
    cores = 4
    memory = 8192
    disk_size = 50
  }
  # ... другие VM
}
```

</details>

<details>
<summary><strong>⚙️Интеграция с Ansible</strong></summary>

---

После создания VM, Terraform автоматически:

1. **Генерирует Ansible inventory** файл (`02-ansible/inventory/prod/hosts.yaml`)
   - Группирует хосты по ролям (control plane, worker nodes, ansible control)
   - Добавляет переменные для каждой группы

2. **Копирует файлы на Ansible control VM** через скрипт `push_ansible_files.sh`:
   - Inventory файл
   - Playbooks и roles из `02-ansible/playbooks/` и `02-ansible/roles/`
   - Helm values файлы (из `02-ansible/playbooks/argocd/` и `02-ansible/playbooks/ingress-nginx/`)
   - SSH ключи
   - Group variables

3. **Копирует ArgoCD Applications** на Kubernetes control plane через скрипт `push_argocd_applications.sh`:
   - Все файлы из `03-argocd/`
   - Размещает в `/home/<user>/argocd-applications/`

### Скрипты копирования

**`push_ansible_files.sh`** - копирует Ansible файлы:
- Выполняется автоматически после создания VM
- Копирует все необходимые файлы для работы Ansible
- Настраивает структуру директорий на удаленном хосте

**`push_argocd_applications.sh`** - копирует ArgoCD Applications:
- Выполняется автоматически после создания VM
- Копирует Applications на control plane ноду
- Готовит файлы для развертывания через ArgoCD

Подробнее см. `02-ansible/README.md`

</details>

<details>
<summary><strong>⚙️Модуль base-vm-cloudinit</strong></summary>

---

Модуль `modules/base-vm-cloudinit` создает виртуальные машины в Proxmox с использованием cloud-init для начальной настройки.

### Входные переменные

Основные переменные модуля:
- `vm_name` - имя виртуальной машины
- `vm_id` - уникальный ID VM
- `template_vm_id` - ID шаблона для клонирования
- `ipv4_address` - IPv4 адрес
- `cores`, `memory`, `disk_size` - ресурсы VM
- `ssh_public_key` - публичный SSH ключ
- `cloud_init_config` - конфигурация cloud-init

Полный список см. `modules/base-vm-cloudinit/variables.tf`

### Outputs

Модуль экспортирует следующие outputs:

- `vms` - Map всех созданных VM с их параметрами
- `vms_by_hostname` - Map VM по hostname
- `vm_ips` - Список всех IP адресов
- `vm_ips_map` - Map IP адресов к hostname
- `vm_ids_map` - Map VM IDs к hostname
- `cloudinit_files` - Информация о созданных cloud-init файлах

### Использование outputs

```hcl
# В live/main.tf или других модулях
output "all_vm_ips" {
  value = module.vm-cloudinit.vm_ips
}

output "ansible_control_ip" {
  value = module.vm-cloudinit.vms_by_hostname["ansible-control-01"].ipv4
}
```

### Cloud-init шаблоны

Модуль использует различные cloud-init шаблоны для разных типов VM:

- **`ansible-control.yaml.tftpl`** - для Ansible control VM
- **`k8s-control.yaml.tftpl`** - для Kubernetes control plane нод
- **`k8s-worker.yaml.tftpl`** - для Kubernetes worker нод

Каждый шаблон настраивает:
- Пользователей и SSH ключи
- Сетевые настройки
- Базовую конфигурацию системы
- Необходимые пакеты

</details>

<details>
<summary><strong>🔧Управление State</strong></summary>

---

### Локальный State (по умолчанию)

State хранится локально в файле `terraform.tfstate`. Это подходит для разработки, но не рекомендуется для production.

⚠️ **Важно**: Файл `terraform.tfstate` содержит чувствительную информацию и не должен коммититься в репозиторий.

### Remote Backend

Для production рекомендуется использовать remote backend. См. `live/backend.tf.example` для примеров конфигурации.

Поддерживаемые backends:
- **Terraform Cloud** - управляемый сервис от HashiCorp
- **AWS S3** - с DynamoDB для state locking
- **Azure Storage** - с state locking
- **Google Cloud Storage** - с state locking
- **HashiCorp Consul** - для распределенных систем

### Пример конфигурации Remote Backend

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "lab-home/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

</details>

<details>
<summary><strong>🔧Управление SSH ключами</strong></summary>

---

### Структура SSH ключей

В проекте используются SSH ключи для двух целей:
1. **Подключение к Proxmox** - для операций провайдера (создание VM, управление)
2. **Подключение к созданным VM** - для Ansible и копирования файлов

### Где хранить SSH ключи

#### Вариант 1: В директории `keys/` (рекомендуется для проекта)

```bash
# Создайте ключи в директории keys/
cd live
ssh-keygen -t ed25519 -f keys/id_ed25519 -N ""

# Убедитесь, что права установлены правильно
chmod 600 keys/id_ed25519
chmod 644 keys/id_ed25519.pub
```

В `terraform.tfvars`:
```hcl
proxmox_ssh_key_path = "keys/id_ed25519"
ansible_ssh_key_path = "keys/id_ed25519"
```

**Преимущества:**
- Все ключи проекта в одном месте
- Легко управлять разными ключами для разных окружений
- Не зависит от системных настроек пользователя

#### Вариант 2: В стандартной директории `~/.ssh/`

```bash
# Создайте ключи стандартным способом
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
```

В `terraform.tfvars`:
```hcl
proxmox_ssh_key_path = null  # Использует ~/.ssh/id_ed25519 по умолчанию
ansible_ssh_key_path = "keys/id_ed25519"  # Или укажите путь к ключу для Ansible
```

**Преимущества:**
- Стандартное расположение
- Удобно для личных проектов
- Автоматически используется SSH agent

#### Вариант 3: SSH Agent (рекомендуется для CI/CD)

Для CI/CD или повышенной безопасности используйте SSH agent:

```bash
# Запустите SSH agent и добавьте ключ
eval $(ssh-agent)
ssh-add ~/.ssh/id_ed25519
# или
ssh-add keys/id_ed25519
```

В `terraform.tfvars`:
```hcl
proxmox_use_ssh_agent = true
proxmox_ssh_key_path = null  # Не нужен при использовании agent
```

**Преимущества:**
- Ключ не хранится на диске в открытом виде
- Безопаснее для CI/CD
- Удобно для автоматизации

### Создание SSH ключей

```bash
# Создание нового ключа Ed25519 (рекомендуется)
ssh-keygen -t ed25519 -C "your_email@example.com" -f keys/id_ed25519

# Или RSA (если Ed25519 не поддерживается)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f keys/id_ed25519
```

### Безопасные практики

1. **Права доступа:**
   ```bash
   chmod 600 keys/id_ed25519      # Приватный ключ - только чтение для владельца
   chmod 644 keys/id_ed25519.pub  # Публичный ключ - можно читать всем
   ```

2. **Разные ключи для разных целей:**
   - Один ключ для Proxmox
   - Другой ключ для созданных VM (Ansible)
   - Это повышает безопасность

3. **Ротация ключей:**
   - Периодически обновляйте ключи
   - Удаляйте старые ключи из авторизованных

4. **CI/CD:**
   - Используйте SSH agent или secrets management
   - Никогда не храните ключи в коде или переменных окружения CI/CD напрямую
   - Используйте зашифрованные секреты (GitHub Secrets, GitLab CI Variables, etc.)

### Публичный ключ для VM

Публичный ключ (`ssh_public_key`) добавляется во все создаваемые VM через cloud-init:

```hcl
# В terraform.tfvars
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... user@host"
```

Получить публичный ключ:
```bash
cat keys/id_ed25519.pub
# или
cat ~/.ssh/id_ed25519.pub
```

</details>

<details>
<summary><strong>🔍Валидация и тестирование</strong></summary>

---

### Локальная валидация

Используйте скрипт валидации для проверки конфигурации:

```bash
# Проверка форматирования и синтаксиса
./scripts/validate.sh

# Автоматическое исправление форматирования
./scripts/validate.sh --fix

# Только проверка форматирования
./scripts/validate.sh --check-format
```

Скрипт выполняет:
- Проверку форматирования Terraform файлов
- Валидацию синтаксиса конфигурации
- Проверку переменных и модулей
- Базовую проверку безопасности (поиск возможных секретов)

### Pre-commit hooks

Для автоматической проверки перед коммитом установите pre-commit hooks:

```bash
pip install pre-commit
pre-commit install
```

Hooks автоматически проверяют:
- Форматирование Terraform файлов
- Валидацию синтаксиса
- Наличие секретов в файлах

### CI/CD валидация

GitHub Actions workflow автоматически валидирует конфигурацию при push и pull request.
См. `.github/workflows/validate.yml` для деталей.

</details>

<details>
<summary><strong>🔧Устранение неполадок</strong></summary>

---

### Проблемы с подключением к Proxmox

**Симптом:** Ошибка подключения к Proxmox API

**Решение:**
```bash
# Проверьте доступность API endpoint
curl -k https://pve.example.com:8006/api2/json/version

# Проверьте API токен
curl -k -H "Authorization: PVEAPIToken=YOUR_TOKEN" https://pve.example.com:8006/api2/json/version

# Проверьте настройки firewall
```

### Проблемы с SSH подключением к VM

**Симптом:** "Permission denied (publickey)"

**Решение:**
```bash
# Проверьте, что SSH ключ правильно добавлен в ssh_public_key
cat terraform.tfvars | grep ssh_public_key

# Проверьте, что VM запущена
terraform show

# Проверьте сетевые настройки и доступность IP адресов
ping <vm_ip>
```

### Проблемы с копированием файлов Ansible

**Симптом:** Скрипт `push_ansible_files.sh` не может скопировать файлы

**Решение:**
```bash
# Проверьте логи скрипта
terraform apply  # Смотрите вывод скрипта

# Убедитесь, что Ansible control VM доступна по SSH
ssh -i keys/id_ed25519 ubuntu@<ansible_control_ip>

# Проверьте права на SSH ключ
chmod 600 keys/id_ed25519
```

### Проблемы с валидацией

**Симптом:** Ошибки валидации Terraform

**Решение:**
```bash
# Убедитесь, что Terraform >= 1.0 установлен
terraform version

# Проверьте, что все модули инициализированы
terraform init

# Запустите валидацию с флагом --fix для автоматического исправления форматирования
./scripts/validate.sh --fix
```

### Проблемы с State

**Симптом:** State файл поврежден или не синхронизирован

**Решение:**
```bash
# Проверьте состояние
terraform state list

# Обновите state
terraform refresh

# При необходимости восстановите из backup
cp terraform.tfstate.backup terraform.tfstate
```

</details>

<details>
<summary><strong>⚠️Безопасность</strong></summary>

---

⚠️ **Важно**: 

- **Никогда не коммитьте** `terraform.tfvars` в репозиторий (уже в `.gitignore`)
- **Не коммитьте** приватные SSH ключи (директория `keys/` в `.gitignore`)
- **Используйте переменные окружения** или secrets management для чувствительных данных
- **Настройте remote backend** с encryption для production
- **Используйте SSH agent** в CI/CD окружениях
- **Регулярно ротируйте** SSH ключи и API токены
- **Ограничьте права** API токенов в Proxmox (принцип минимальных привилегий)
- **Используйте отдельные токены** для разных окружений (dev, staging, production)

### Best Practices

1. **Secrets Management:**
   - Используйте HashiCorp Vault, AWS Secrets Manager, или аналоги
   - Храните API токены и ключи в зашифрованном виде
   - Ротация секретов должна быть автоматизирована

2. **Access Control:**
   - Используйте отдельные API токены для Terraform
   - Ограничьте права токенов только необходимыми операциями
   - Регулярно проверяйте и удаляйте неиспользуемые токены

3. **State Security:**
   - Используйте remote backend с encryption
   - Включите state locking для предотвращения конфликтов
   - Регулярно делайте backup state файлов

4. **Network Security:**
   - Ограничьте доступ к Proxmox API через firewall
   - Используйте VPN или private network для доступа
   - Включите TLS/SSL для всех API соединений

</details>