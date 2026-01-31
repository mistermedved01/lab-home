# Модуль base-vm-cloudinit

Terraform модуль для создания виртуальных машин в Proxmox VE с использованием cloud-init для начальной настройки.

## Описание

Этот модуль создает виртуальные машины в Proxmox, клонируя их из шаблона и настраивая через cloud-init. Модуль поддерживает:

- Клонирование VM из шаблона
- Настройку сетевых параметров (IP, gateway, CIDR)
- Cloud-init конфигурацию для начальной настройки
- Гибкую настройку ресурсов (CPU, память, диск)
- Автоматический запуск VM после создания

## Использование

### Базовый пример

```hcl
module "vms" {
  source = "../../modules/base-vm-cloudinit"

  proxmox_endpoint    = "https://192.168.40.143:8006/"
  proxmox_api_token   = var.proxmox_api_token
  node_name           = "pve-node-01"
  datastore_id        = "local-lvm"
  network_bridge      = "vmbr0"
  ssh_authorized_keys = [var.ssh_public_key]
  vm_user             = "ubuntu"
  ansible_version     = "13.3.0-1ppa~noble"

  vm_list = {
    web-server-01 = {
      vm_hostname     = "web-server-01"
      vm_ip           = "192.168.40.100"
      vm_id           = 2000
      vm_cores        = 2
      vm_memory       = 4096
      vm_disk_size    = 50
      cloud_init_file = "k8s-worker.yaml.tftpl"
    }
  }

  gateway_ip            = "192.168.40.1"
  template_vm_id        = 9000
  snippets_datastore_id = "local"
  disk_datastore_id     = "local-lvm"
  network_cidr          = 24
}
```

### Пример с несколькими VM

```hcl
module "k8s_cluster" {
  source = "../../modules/base-vm-cloudinit"

  # ... базовые параметры ...

  vm_list = {
    k8s-control-01 = {
      vm_hostname     = "k8s-control-01"
      vm_ip           = "192.168.40.10"
      vm_id           = 1001
      vm_cores        = 4
      vm_memory       = 8192
      vm_disk_size    = 100
      cloud_init_file = "k8s-control.yaml.tftpl"
    }
    k8s-worker-01 = {
      vm_hostname     = "k8s-worker-01"
      vm_ip           = "192.168.40.11"
      vm_id           = 1002
      vm_cores        = 4
      vm_memory       = 8192
      vm_disk_size    = 100
      cloud_init_file = "k8s-worker.yaml.tftpl"
    }
    k8s-worker-02 = {
      vm_hostname     = "k8s-worker-02"
      vm_ip           = "192.168.40.12"
      vm_id           = 1003
      vm_cores        = 2
      vm_memory       = 4096
      vm_disk_size    = 50
      cloud_init_file = "k8s-worker.yaml.tftpl"
    }
  }

  gateway_ip            = "192.168.40.1"
  template_vm_id        = 9000
  snippets_datastore_id = "local"
  disk_datastore_id     = "local-lvm"
  network_cidr          = 24
}
```

## Входные переменные

### Обязательные переменные

| Имя | Тип | Описание |
|-----|-----|----------|
| `proxmox_endpoint` | `string` | URL API Proxmox (например `https://192.168.40.143:8006/`) |
| `proxmox_api_token` | `string` | API токен для аутентификации в Proxmox (sensitive) |
| `node_name` | `string` | Имя узла Proxmox, на котором создаются VM |
| `datastore_id` | `string` | Хранилище для VM дисков |
| `network_bridge` | `string` | Сетевой мост (например `vmbr0`) |
| `ssh_authorized_keys` | `list(string)` | Список публичных SSH ключей для доступа к VM |
| `vm_list` | `map(object)` | Map VM для создания (см. структуру ниже) |
| `gateway_ip` | `string` | IP-адрес шлюза для VM |
| `disk_datastore_id` | `string` | Хранилище для дисков VM |

### Опциональные переменные

| Имя | Тип | По умолчанию | Описание |
|-----|-----|--------------|----------|
| `vm_user` | `string` | `"ubuntu"` | Имя пользователя для создания на VM |
| `template_vm_id` | `number` | `9000` | ID шаблона VM для клонирования |
| `snippets_datastore_id` | `string` | `"local"` | Хранилище для cloud-init snippets |
| `network_cidr` | `number` | `24` | CIDR маска подсети (например, 24 для /24) |
| `ansible_version` | `string` | `"13.3.0-1ppa~noble"` | Версия Ansible (используется в ansible-control). Для последней из PPA укажите `"latest"`. |

### Структура vm_list

Каждая запись в `vm_list` должна иметь следующую структуру:

```hcl
{
  vm_hostname     = string  # Имя хоста VM (до 63 символов)
  vm_ip           = string  # IPv4 адрес VM
  vm_id           = number  # Уникальный ID VM в Proxmox (1-99999)
  vm_cores        = number  # Количество CPU ядер (1-64)
  vm_memory       = number  # Память в МБ (максимум 1TB)
  vm_disk_size    = number  # Размер диска в ГБ (максимум 10TB)
  cloud_init_file = string  # Имя файла cloud-init шаблона из cloud-init/
}
```

## Outputs

Модуль экспортирует следующие outputs:

### `vms`

Map всех созданных VM с их основными параметрами.

```hcl
output "vms" {
  value = module.vms.vms
}
```

Пример вывода:
```hcl
{
  "web-server-01" = {
    id       = 2000
    name     = "web-server-01"
    node     = "pve-node-01"
    ipv4     = "192.168.40.100/24"
    hostname = "web-server-01"
  }
}
```

### `vms_by_hostname`

Map VM по hostname для удобного поиска.

```hcl
output "vms_by_hostname" {
  value = module.vms.vms_by_hostname
}
```

### `vm_ips`

Список всех IP адресов созданных VM.

```hcl
output "vm_ips" {
  value = module.vms.vm_ips
}
# ["192.168.40.100/24", "192.168.40.101/24"]
```

### `vm_ips_map`

Map IP адресов к hostname.

```hcl
output "vm_ips_map" {
  value = module.vms.vm_ips_map
}
# {
#   "192.168.40.100/24" = "web-server-01"
#   "192.168.40.101/24" = "web-server-02"
# }
```

### `vm_ids_map`

Map VM IDs к hostname.

```hcl
output "vm_ids_map" {
  value = module.vms.vm_ids_map
}
# {
#   2000 = "web-server-01"
#   2001 = "web-server-02"
# }
```

### `cloudinit_files`

Информация о созданных cloud-init файлах.

```hcl
output "cloudinit_files" {
  value = module.vms.cloudinit_files
}
```

## Cloud-init шаблоны

Модуль использует cloud-init шаблоны из директории `cloud-init/`. Доступные шаблоны:

- `ansible-control.yaml.tftpl` - для Ansible control node
- `k8s-control.yaml.tftpl` - для Kubernetes control plane nodes
- `k8s-worker.yaml.tftpl` - для Kubernetes worker nodes

Шаблоны используют следующие переменные:
- `${hostname}` - имя хоста VM
- `${vm_user}` - имя пользователя
- `${ssh_authorized_keys}` - список SSH ключей
- `${ansible_package}` - пакет для apt: `ansible` при `ansible_version == "latest"`, иначе `ansible=VERSION` (только для ansible-control)

## Требования

- Terraform >= 1.0
- Proxmox VE >= 7.0
- Proxmox provider >= 0.89.1
- Шаблон VM в Proxmox для клонирования

## Ограничения

- Все VM создаются на одном узле Proxmox (указанном в `node_name`)
- Все VM используют один сетевой мост
- Все VM используют одинаковый gateway и CIDR
- VM ID должны быть уникальными в пределах Proxmox кластера

## Примеры использования outputs

### Получить IP адрес конкретной VM

```hcl
output "web_server_ip" {
  value = module.vms.vms_by_hostname["web-server-01"].ipv4
}
```

### Создать inventory для Ansible

```hcl
locals {
  ansible_inventory = {
    for k, vm in module.vms.vms : vm.hostname => {
      ansible_host = vm.ipv4
    }
  }
}
```

### Использовать в других модулях

```hcl
module "load_balancer" {
  source = "../load-balancer"
  
  backend_servers = [
    for vm in module.vms.vms : vm.ipv4
  ]
}
```

## Валидация

Модуль включает валидацию всех входных переменных:

- Проверка формата URL для `proxmox_endpoint`
- Проверка формата SSH ключей
- Проверка диапазонов значений (CPU, память, диск)
- Проверка формата IP адресов
- Проверка формата hostname

## Troubleshooting

### VM не запускается

- Проверьте, что шаблон VM существует и доступен
- Убедитесь, что VM ID уникален
- Проверьте логи cloud-init на VM

### Проблемы с сетью

- Убедитесь, что IP адреса не конфликтуют
- Проверьте настройки сетевого моста
- Проверьте доступность gateway

### Проблемы с cloud-init

- Проверьте, что файл cloud-init шаблона существует
- Убедитесь, что snippets datastore доступен
- Проверьте логи cloud-init: `/var/log/cloud-init-output.log`

## Лицензия

См. основной LICENSE файл проекта.

