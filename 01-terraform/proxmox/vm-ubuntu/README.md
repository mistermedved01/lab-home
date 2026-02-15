# Terraform Infrastructure

Этот каталог содержит Terraform конфигурацию для развертывания виртуальных машин на **Ubuntu** в Proxmox и автоматической настройки инфраструктуры Kubernetes с помощью Ansible.

<details>
<summary><strong>📋Описание</strong></summary>

---

Terraform конфигурация автоматизирует:

- **Создание виртуальных машин на Ubuntu** в Proxmox VE (образ cloud-init, например Noble)
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
01-terraform/proxmox/vm-ubuntu/
├── live/                         # Environment-specific конфигурация
│   ├── main.tf                   # Основная конфигурация
│   ├── variables.tf              # Определение переменных
│   ├── providers.tf              # Конфигурация провайдеров
│   ├── versions.tf               # Версии провайдеров
│   ├── outputs.tf                # Outputs конфигурации
│   ├── terraform.tfvars          # Значения переменных (не коммитится)
│   ├── terraform.tfvars.example  # Пример конфигурации
│   ├── keys/                     # SSH ключи (не коммитятся)
│   │   ├── id_ed25519            # Приватный ключ
│   │   └── id_ed25519.pub        # Публичный ключ
│   ├── scripts/                  # Вспомогательные скрипты
│   │   ├── push_ansible_files.sh       # Копирование Ansible файлов
│   │   └── push_argocd_applications.sh # Копирование ArgoCD Applications
│   └── templates/                # Terraform шаблоны
│       └── ansible_inventory.yaml.tftpl  # Шаблон Ansible inventory
└── modules/                      # Переиспользуемые модули
    └── base-vm-cloudinit/         # Модуль создания VM с cloud-init
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        ├── versions.tf
        └── cloud-init/            # Cloud-init шаблоны
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
   cd 01-terraform/proxmox/vm-ubuntu/live
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Отредактируйте `terraform.tfvars`** и заполните реальные значения:
   - `proxmox_nodes` — узлы Proxmox (endpoint, api_token, node_name для каждого; в кластере один токен для всех узлов)
   - `ssh_public_key` — ваш публичный SSH ключ
   - `vm_list` — список VM; у каждой укажите `proxmox_node` — ключ из `proxmox_nodes`, на каком узле создавать VM

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
cd 01-terraform/proxmox/vm-ubuntu/live

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
| `proxmox_nodes` | Map узлов Proxmox: ключ — id ноды (например `pve-node-01`), значение — endpoint, api_token, node_name, опционально datastore_id, network_bridge | Да | - |
| `gateway_ip` | IP шлюза для VM | Да | - |
| `network_cidr` | Маска подсети (например 24) | Нет | `24` |
| `ssh_public_key` | Публичный SSH ключ для VM | Да | - |
| `vm_list` | Список VM: vm_hostname, vm_ip, vm_id, vm_cores, vm_memory, vm_disk_size, cloud_init_file, role, **proxmox_node** (ключ из proxmox_nodes) | Да | - |
| `vm_user` | Имя пользователя на VM | Нет | `ubuntu` |
| `ansible_control_vm_key` | Ключ в vm_list для Ansible control VM | Нет | `ansible_control-01` |
| `ansible_ssh_key_path` | Путь к SSH ключу для Ansible control VM | Нет | `keys/id_ed25519` |
| `iso_image` | Путь к ISO в Proxmox (например `local:iso/noble-server-cloudimg-amd64.img`) | Нет | `null` |

Полный список переменных см. в `live/variables.tf`.

### Использование переменных окружения

Для безопасности можно использовать переменные окружения вместо `terraform.tfvars`:

```bash
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
# Токен для Proxmox задаётся внутри proxmox_nodes в tfvars или через TF_VAR (сложнее для map)
terraform apply
```

### Пример конфигурации

```hcl
# terraform.tfvars (поддержка нескольких узлов Proxmox)
proxmox_nodes = {
  "pve-node-01" = {
    endpoint       = "https://192.168.7.151:8006/"
    api_token      = "terraform@pve!terraform-token=YOUR_TOKEN"
    node_name      = "pve-node-01"
    datastore_id   = "local"
    network_bridge = "vmbr0"
  }
  "pve-node-02" = {
    endpoint       = "https://192.168.7.152:8006/"
    api_token      = "terraform@pve!terraform-token=YOUR_TOKEN"
    node_name      = "pve-node-02"
    datastore_id   = "local"
    network_bridge = "vmbr0"
  }
}

gateway_ip = "192.168.7.1"
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... user@host"

vm_list = {
  ansible_control-01 = {
    vm_hostname     = "ansible-control-01"
    vm_ip           = "192.168.7.161"
    vm_id           = 1001
    vm_cores        = 2
    vm_memory       = 2000
    vm_disk_size    = 20
    cloud_init_file = "ansible-control.yaml.tftpl"
    role            = "ansible"
    proxmox_node    = "pve-node-01"
  }
  k8s_control-01 = {
    vm_hostname     = "k8s-control-01"
    vm_ip           = "192.168.7.162"
    vm_id           = 1002
    vm_cores        = 4
    vm_memory       = 6000
    vm_disk_size    = 30
    cloud_init_file = "k8s-control.yaml.tftpl"
    role            = "k8s_control"
    proxmox_node    = "pve-node-01"
  }
  k8s_worker-01 = {
    vm_hostname     = "k8s-worker-01"
    vm_ip           = "192.168.7.163"
    vm_id           = 1003
    vm_cores        = 4
    vm_memory       = 8000
    vm_disk_size    = 30
    cloud_init_file = "k8s-worker.yaml.tftpl"
    role            = "k8s_worker"
    proxmox_node    = "pve-node-01"
  }
  k8s_worker-02 = {
    vm_hostname     = "k8s-worker-02"
    vm_ip           = "192.168.7.164"
    vm_id           = 1004
    vm_cores        = 4
    vm_memory       = 8000
    vm_disk_size    = 30
    cloud_init_file = "k8s-worker.yaml.tftpl"
    role            = "k8s_worker"
    proxmox_node    = "pve-node-02"
  }
}
```

</details>

<details>
<summary><strong>⚙️Интеграция с Ansible</strong></summary>

---

После создания VM Terraform автоматически:

1. **Генерирует Ansible inventory** (`02-ansible/inventory/prod/hosts.yaml`):
   - Группы: `kube_control_plane`, `kube_node`, `k8s_cluster`, `proxmox`
   - IP VM берутся из `vm_list`; в группу `proxmox` попадают все узлы из `proxmox_nodes` (IP из endpoint каждого узла)

2. **Копирует файлы на Ansible control VM** через скрипт `push_ansible_files.sh`:
   - Inventory, playbooks, roles, Helm values, SSH ключи, group variables

3. **Копирует ArgoCD Applications** на Kubernetes control plane через скрипт `push_argocd_applications.sh`:
   - Файлы из `03-argocd/` в `/home/<user>/argocd-applications/`

### Proxmox в inventory

Группа `proxmox` в inventory используется playbook'ом node-exporter. В неё попадают все узлы из `proxmox_nodes` (pve-node-01, pve-node-02 и т.д.); IP каждого хоста извлекается из URL `endpoint`. Подключение по SSH под пользователем **root**. Убедитесь, что на каждом узле Proxmox настроен вход root по вашему SSH ключу (например, `ssh-copy-id root@<proxmox_ip>`).

### Получение kubeconfig

После выполнения Ansible playbook'ов (control-plane, cni, worker) kubeconfig лежит на control plane ноде:
- `/etc/kubernetes/admin.conf` (root)
- `/home/<vm_user>/.kube/config` (пользователь из inventory)

Скопировать на локальную машину:
```bash
# IP control plane — из terraform output или inventory
scp -i keys/id_ed25519 ubuntu@<k8s_control_ip>:~/.kube/config ~/.kube/config-lab-home
# или с хоста: ssh ubuntu@<k8s_control_ip> "sudo cat /etc/kubernetes/admin.conf" > ~/.kube/config-lab-home
export KUBECONFIG=~/.kube/config-lab-home
```

### Скрипты копирования

| Скрипт | Назначение |
|--------|------------|
| `push_ansible_files.sh` | Копирование inventory, playbooks, roles, ключей на Ansible control VM |
| `push_argocd_applications.sh` | Копирование `03-argocd/` на Kubernetes control plane |

Подробнее см. `02-ansible/README.md`.

</details>

<details>
<summary><strong>⚙️Модуль base-vm-cloudinit</strong></summary>

---

Модуль `modules/base-vm-cloudinit` создаёт виртуальные машины в Proxmox с использованием cloud-init. В `live/main.tf` модуль вызывается **по одному разу на каждый узел** из `proxmox_nodes`; каждому вызову передаётся свой провайдер (alias), параметры узла (endpoint, api_token, node_name, datastore_id, network_bridge) и отфильтрованный `vm_list` (только VM с соответствующим `proxmox_node`).

### Входные переменные модуля

Модуль получает от `live/main.tf`: `proxmox_endpoint`, `proxmox_api_token`, `node_name`, `datastore_id`, `network_bridge`, `ssh_authorized_keys`, `vm_user`, `vm_list` (без полей role и proxmox_node), `gateway_ip`, `network_cidr`, `iso_image`, `snippets_datastore_id`, `disk_datastore_id`, `ansible_version`.

Полный список см. в `modules/base-vm-cloudinit/variables.tf`.

### Outputs (live/outputs.tf)

Конфигурация `live` экспортирует:

| Output | Описание |
|--------|----------|
| `vms` | Map всех созданных VM с параметрами |
| `vms_by_hostname` | Map VM по hostname |
| `vm_ips` | Список IP адресов VM (CIDR) |
| `vm_ips_map` | Map IP → hostname |
| `ansible_control_ip` | IP Ansible control VM |
| `k8s_control_plane_ips` | IP адреса Kubernetes control plane |
| `k8s_worker_ips` | IP адреса Kubernetes worker nodes |

### Пример использования outputs

```bash
cd live
terraform output ansible_control_ip
terraform output k8s_control_plane_ips
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
<summary><strong>🔍Валидация</strong></summary>

---

### Локальная проверка

```bash
cd live
terraform init
terraform validate
terraform fmt -check -recursive
```

### Pre-commit (опционально)

При наличии pre-commit в проекте можно настроить проверки перед коммитом (форматирование Terraform, проверка секретов и т.п.).

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

### pve-node-01: Permission denied (publickey) / UNREACHABLE

**Симптом:** Ansible не подключается к `pve-node-01` (например, `root@192.168.x.x: Permission denied`).

**Причины:** В inventory для группы `proxmox` должны быть IP хостов Proxmox (извлекаются из `proxmox_nodes` по полю endpoint каждого узла). Для playbook node-exporter нужен вход по SSH под **root** на каждый узел Proxmox.

**Решение:**
```bash
# Проверьте hosts.yaml: у pve-node-01 ansible_host должен быть IP Proxmox, не шлюза
# Добавьте свой ключ на Proxmox для root:
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@<proxmox_ip>
# Или пропустите playbook node-exporter: --skip-tags node-exporter
```

### Проблемы с копированием файлов Ansible

**Симптом:** Скрипт `push_ansible_files.sh` не может скопировать файлы

**Решение:**
```bash
# Проверьте вывод при terraform apply
# Убедитесь, что Ansible control VM доступна по SSH
ssh -i keys/id_ed25519 ubuntu@<ansible_control_ip>

# Проверьте права на SSH ключ
chmod 600 keys/id_ed25519
```

### Проблемы с валидацией

**Симптом:** Ошибки валидации Terraform

**Решение:**
```bash
terraform version   # Terraform >= 1.0
terraform init
terraform validate
terraform fmt -recursive   # автоформатирование
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