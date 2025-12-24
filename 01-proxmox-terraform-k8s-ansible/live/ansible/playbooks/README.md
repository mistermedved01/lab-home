# Руководство по использованию Ansible Playbooks

Этот документ описывает, как использовать Ansible Playbooks для развертывания Kubernetes кластера.

## Структура Playbooks

Проект содержит следующие playbooks:

1. **`site.yml`** - Главный playbook, который запускает все остальные в правильном порядке
2. **`common-setup.yml`** - Подготовка всех нод (отключение swap, настройка ядра, установка зависимостей)
3. **`k8s-control-setup.yml`** - Инициализация Kubernetes control plane
4. **`cni-setup.yml`** - Установка CNI плагина (Flannel)
5. **`k8s-worker-setup.yml`** - Присоединение worker nodes к кластеру

## Подготовка

После выполнения Terraform, файлы Ansible автоматически копируются на Ansible Control VM:
- `inventory.yaml` → `/etc/ansible/inventory.yaml`
- Playbooks → `/etc/ansible/playbooks/`
- SSH ключ → `~/.ssh/id_ed25519`

## Подключение к Ansible Control VM

1. Получите IP адрес Ansible Control VM из Terraform output или inventory:
   ```bash
   # Из Terraform
   terraform output
   
   # Или из inventory
   cat ansible/inventory.yaml
   ```

2. Подключитесь к VM:
   ```bash
   ssh -i keys/id_ed25519 ubuntu@<ANSIBLE_CONTROL_IP>
   ```

## Использование Playbooks

### Вариант 1: Полная установка (рекомендуется)

Запустите главный playbook, который выполнит все шаги автоматически:

```bash
cd /etc/ansible/playbooks
ansible-playbook playbooks/site.yml
```

Этот playbook выполнит:
1. Подготовку всех нод (`common-setup.yml`)
2. Инициализацию control plane (`k8s-control-setup.yml`)
3. Установку CNI (`cni-setup.yml`)
4. Присоединение worker nodes (`k8s-worker-setup.yml`)

### Вариант 2: Пошаговая установка

Если нужно выполнить установку по шагам:

#### Шаг 1: Подготовка всех нод
```bash
cd /etc/ansible/playbooks
ansible-playbook playbooks/common-setup.yml
```

#### Шаг 2: Инициализация control plane
```bash
ansible-playbook playbooks/k8s-control-setup.yml
```

После выполнения этого playbook будет создан файл `.kubeadm-join-command` с командой для присоединения worker nodes.

#### Шаг 3: Установка CNI плагина
```bash
ansible-playbook playbooks/cni-setup.yml
```

#### Шаг 4: Присоединение worker nodes
```bash
ansible-playbook playbooks/k8s-worker-setup.yml
```

## Проверка установки

После завершения установки проверьте статус кластера:

```bash
# На control plane ноде
kubectl get nodes
kubectl get pods --all-namespaces
```

## Переменные конфигурации

Переменные настраиваются в файлах `group_vars/`:

- **`group_vars/all/main.yml`** - Общие переменные:
  - `kubernetes_version` - версия Kubernetes
  - `pod_network_cidr` - CIDR для pod сети
  - `cni_manifest_url` - URL манифеста CNI плагина

- **`group_vars/kube_control_plane/main.yml`** - Настройки control plane:
  - `service_cidr` - CIDR для сервисов
  - `cluster_dns` - DNS адрес кластера

- **`group_vars/kube_node/main.yml`** - Настройки worker nodes

## Полезные команды

### Проверка inventory
```bash
ansible all -i /etc/ansible/inventory.yaml -m ping
```

### Проверка конкретной группы
```bash
ansible kube_control_plane -i /etc/ansible/inventory.yaml -m ping
ansible kube_node -i /etc/ansible/inventory.yaml -m ping
```

### Запуск playbook с дополнительными параметрами
```bash
# С повышенной детализацией
ansible-playbook playbooks/site.yml -v

# С максимальной детализацией
ansible-playbook playbooks/site.yml -vvv

# Только для определенных хостов
ansible-playbook playbooks/common-setup.yml --limit kube_control_plane
```

### Проверка синтаксиса playbook
```bash
ansible-playbook playbooks/site.yml --syntax-check
```

## Устранение проблем

### Если playbook завершился с ошибкой

1. Проверьте логи выполнения
2. Проверьте доступность хостов:
   ```bash
   ansible all -i /etc/ansible/inventory.yaml -m ping
   ```
3. Проверьте SSH подключение вручную:
   ```bash
   ssh -i ~/.ssh/id_ed25519 ubuntu@<NODE_IP>
   ```

### Если нужно перезапустить установку

Playbooks идемпотентны - их можно запускать повторно. Они проверяют текущее состояние и выполняют только необходимые изменения.

### Если нужно переинициализировать кластер

На control plane ноде:
```bash
sudo kubeadm reset
```

Затем запустите playbooks заново.

## Структура Inventory

Inventory файл (`/etc/ansible/inventory.yaml`) содержит группы:

- **`kube_control_plane`** - Control plane ноды
- **`kube_node`** - Worker ноды
- **`k8s_cluster`** - Все ноды кластера (включает обе группы выше)
- **`etcd`** - Ноды etcd (обычно совпадает с control plane)

## Дополнительная информация

- Все playbooks используют `become: yes` для выполнения с правами root
- SSH ключ должен быть доступен на Ansible Control VM
- Inventory автоматически генерируется Terraform на основе `vm_list`
