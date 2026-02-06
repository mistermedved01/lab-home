# 🏠lab-home

## 📄О проекте

**lab-home** - это домашняя платформа для экспериментов с Kubernetes. Система автоматически поднимает виртуальные машины в Proxmox, настраивает k8s кластер через Ansible и разворачивает приложения с помощью ArgoCD. В итоге получается полностью воспроизводимая инфраструктура, которую можно пересоздать в любой момент.

---

## 🏗️Общая архитектура системы

Система состоит из трех основных компонентов, работающих последовательно и обеспечивающих полную автоматизацию развертывания:

```mermaid
graph TB
    subgraph "Уровень 1: Инфра"
        Proxmox[Proxmox VE<br/>Гипервизор]
        Terraform[Terraform<br/>IaC]
    end
    
    subgraph "Уровень 2: Конфигурация"
        Ansible[Ansible<br/>Configuration Management]
        AnsibleVM[Ansible Control VM]
    end
    
    subgraph "Уровень 3: Развертывание"
        ArgoCD[ArgoCD<br/>GitOps Controller]
        K8sCluster[Kubernetes Cluster]
    end
    
    subgraph "Уровень 4: Приложения"
        Apps[Приложения<br/>cert-manager, GitLab,<br/>Rancher, Prometheus,<br/>Homepage]
    end
    
    Terraform -->|Создает VM| Proxmox
    Terraform -->|Генерирует inventory| Ansible
    Terraform -->|Копирует файлы| AnsibleVM
    Terraform -->|Копирует Applications| K8sCluster
    
    Ansible -->|Настраивает| K8sCluster
    AnsibleVM -->|Выполняет playbooks| K8sCluster
    
    ArgoCD -->|Управляет| Apps
    K8sCluster -->|Хостит| ArgoCD
    K8sCluster -->|Хостит| Apps
    
    style Terraform fill:#623CE4,color:#fff
    style Ansible fill:#EE0000,color:#fff
    style ArgoCD fill:#EF7B4D,color:#fff
    style K8sCluster fill:#326CE5,color:#fff
```

### 🔗Взаимосвязи компонентов

1. **Terraform** создает базовую инфраструктуру (виртуальные машины) и подготавливает среду для следующих этапов
2. **Ansible** конфигурирует созданные виртуальные машины и развертывает Kubernetes кластер
3. **ArgoCD** управляет жизненным циклом приложений в кластере через GitOps подход

---

<details>
<summary><b>🚀Быстрый старт</b></summary>

---

## ✅Предварительные требования:

Перед началом развертывания убедитесь, что у вас есть:

- **Terraform** >= 1.0 установлен и доступен в PATH
- **Доступ к Proxmox VE** с правами на создание виртуальных машин
- **SSH ключ** для подключения к создаваемым VM
- **ISO образ Ubuntu** загружен в Proxmox (например, noble-server-cloudimg-amd64.img)

---

## 📖Пошаговая инструкция:

### 📋Шаг 1: Подготовка конфигурации Terraform

Заполните файл `terraform.tfvars` по примеру `terraform.tfvars.example`:

```bash
cd 01-terraform/proxmox/vm-ubuntu/live
cp terraform.tfvars.example terraform.tfvars
# Отредактируйте terraform.tfvars и заполните реальными значениями
```

**⚠️Важно:** Укажите корректные значения для следующих параметров. 

----

#### 📝Подробные инструкции и команды для получения каждого значения:

**→ Proxmox endpoint**

Параметр **proxmox_endpoint** в terraform.tfvars задаёт URL API Proxmox.

- **Формат:** `https://IP_АДРЕС:8006/`
- **Как получить:** IP-адрес вашего Proxmox сервера
- **Пример:** `https://192.168.40.143:8006/`

**→ API-токен Proxmox**

Параметр **proxmox_api_token** используется для аутентификации Terraform в Proxmox API.

- **Формат:** `USERNAME@REALM!TOKEN_NAME=TOKEN_VALUE`
- **Создание через командную строку** (на Proxmox хосте):
  ```bash
  # Создать пользователя (если еще не создан)
  pveum user add terraform@pve --password YOUR_PASSWORD
  
  # Создать токен (значение токена будет выведено сразу после создания)
  pveum user token add terraform@pve terraform-token --privsep 0
  # Вывод будет содержать полный токен в формате:
  # terraform@pve!terraform-token=TOKEN_VALUE
  ```

- **⚠️Важно:** Значение токена показывается только при создании и не может быть получено позже!

- **Альтернатива:** создать через веб-интерфейс Proxmox (Datacenter → Permissions → API Tokens)

**→ Публичный SSH-ключ**

Параметр **ssh_public_key** добавляется на создаваемые VM для доступа по SSH.

- **Формат:** `ssh-ed25519 ...` или `ssh-rsa ...`
- **Получение существующего ключа:**
  ```bash
  # Для ed25519 ключа (рекомендуется)
  cat ~/.ssh/id_ed25519.pub
  
  # Или для RSA ключа
  cat ~/.ssh/id_rsa.pub
  ```

- **Создание нового ключа** (если ключа нет):
  ```bash
  # Создать новый ed25519 ключ (рекомендуется)
  ssh-keygen -t ed25519 -C "your_email@example.com"
  
  # Вывести публичный ключ
  cat ~/.ssh/id_ed25519.pub
  ```

- **⚠️Важно:** этот ключ будет добавлен во все создаваемые VM для доступа по SSH

**→ Список виртуальных машин (vm_list)**

Параметр **vm_list** описывает каждую виртуальную машину (hostname, IP, ID, ресурсы).

- **Формат:** объект с параметрами каждой VM (hostname, IP-адрес, ID, ресурсы)
- **Проверка VM ID:** убедитесь, что VM ID не занят в Proxmox (через веб-интерфейс или API)
- **Пример конфигурации:** см. `terraform.tfvars.example`
- **⚠️Важно:**
  - IP-адреса должны быть уникальными и доступными в вашей сети
  - VM ID должны быть уникальными (обычно 100-999 для пользовательских VM)
  - Ресурсы должны соответствовать возможностям Proxmox хоста

---

### 💿Шаг 2: Загрузка ISO образа в Proxmox

В веб-интерфейсе Proxmox:

1. Перейдите в **Datacenter** → выберите **node** → **local** → **ISO Images**
2. Загрузите ISO образ (например, `noble-server-cloudimg-amd64.img`)
3. Убедитесь, что образ доступен в хранилище, указанном в `terraform.tfvars` (обычно `local:iso/`)

---

### 🧪Шаг 3: Тестирование конфигурации Terraform

Перед применением проверьте план развертывания:

```bash
cd 01-terraform/proxmox/vm-ubuntu/live

# Инициализация Terraform (если еще не выполнено)
terraform init

# Просмотр плана изменений
terraform plan
```

Проверьте, что план соответствует ожиданиям: количество VM, их ресурсы, IP-адреса.

---

### 🚀Шаг 4: Применение конфигурации Terraform

Создайте виртуальные машины:

```bash
cd 01-terraform/proxmox/vm-ubuntu/live
terraform apply
```

Terraform автоматически:
- Создаст виртуальные машины в Proxmox
- Настроит cloud-init конфигурации
- Сгенерирует Ansible inventory файл
- Скопирует файлы на Ansible Control VM (`/etc/ansible/`)
- Скопирует ArgoCD Applications на Kubernetes control plane (`~/03-argocd/`)

**Примечание:** После `terraform apply` подождите 2-3 минуты, пока VM полностью загрузятся и станут доступны по SSH. Terraform скрипты автоматически ожидают готовности хостов.

---

### ☸️Шаг 5: Развертывание Kubernetes кластера через Ansible

Подключитесь к Ansible Control VM и запустите главный playbook:

```bash
# Подключение к Ansible Control VM
# IP-адрес можно получить из terraform output или из terraform.tfvars
ssh -i 01-terraform/proxmox/vm-ubuntu/live/keys/id_ed25519 ubuntu@<ANSIBLE_CONTROL_IP>

# Переход в директорию с playbooks
cd /etc/ansible/playbooks

# Запуск главного playbook
ansible-playbook site.yml -i inventory/prod/hosts.yaml
```

Playbook выполнит автоматически:
1. Базовую настройку всех узлов кластера
2. Инициализацию Kubernetes control plane
3. Установку CNI (Flannel)
4. Присоединение worker nodes
5. Установку Helm
6. Установку ingress-nginx
7. Установку ArgoCD

**⚠️Важно:** После завершения playbook автоматически выведет:
- Логин и пароль для доступа к ArgoCD (логин: `admin`)
- URL для доступа к ArgoCD через ingress

---

### 🌐Шаг 6: Настройка DNS и доступ к ArgoCD

Для доступа к ArgoCD через веб-интерфейс необходимо настроить DNS на вашей машине:

**Windows** (`C:\Windows\System32\drivers\etc\hosts`):
```
<IP-адрес_k8s-control-01> argocd.lab-home.com
```

**Linux/macOS** (`/etc/hosts`):
```
<IP-адрес_k8s-control-01> argocd.lab-home.com
```

Замените `<IP-адрес_k8s-control-01>` на реальный IP-адрес вашего Kubernetes control plane узла (например, `192.168.40.145`)

**Примечание:** Если вы планируете развертывать дополнительные приложения через ArgoCD, добавьте их домены в hosts файл:

**Windows** (`C:\Windows\System32\drivers\etc\hosts`):

**Linux/macOS** (`/etc/hosts`):
```
<IP-адрес_k8s-control-01> argocd.lab-home.com
<IP-адрес_k8s-control-01> rancher.lab-home.com
<IP-адрес_k8s-control-01> gitlab.lab-home.com
<IP-адрес_k8s-control-01> homepage.lab-home.com
<IP-адрес_k8s-control-01> grafana.lab-home.com
```

После настройки DNS откройте в браузере:
```
https://argocd.lab-home.com:30443/
```

Используйте учетные данные, выведенные при выполнении Ansible playbook (логин: `admin`, пароль из вывода playbook).

---

### 📦Шаг 7: Развертывание ArgoCD Applications

Подключитесь к Kubernetes control plane и примените манифесты ArgoCD Applications:

```bash
# Подключение к k8s-control-01
ssh -i 01-terraform/proxmox/vm-ubuntu/live/keys/id_ed25519 ubuntu@<K8S_CONTROL_IP>

# Применение манифестов (начинаем с cert-manager, так как он требуется для TLS)
cd ~/03-argocd/cert-manager
kubectl apply -f cert-manager.yaml

# Применение остальных Applications (опционально, можно применить все сразу)
kubectl apply -f ~/03-argocd/cert-manager/clusterissuer-selfsigned.yaml
kubectl apply -f ~/03-argocd/cert-manager/clusterissuer-application.yaml
```

**Примечание:** ArgoCD Applications автоматически копируются Terraform в директорию `~/03-argocd/` на k8s-control-01. Вы можете применить их все сразу или по отдельности в зависимости от ваших потребностей.

---

### ✅Проверка результата

После выполнения всех шагов у вас должен быть:

- ✅ Работающий Kubernetes кластер
- ✅ ArgoCD доступен по адресу `https://argocd.lab-home.com:30443/`
- ✅ Ingress Controller настроен и работает
- ✅ ArgoCD Applications готовы к применению

Для проверки состояния кластера:
```bash
# На k8s-control-01
kubectl get nodes
kubectl get pods -A
kubectl get ingress -A
```

</details>

---

<details>
<summary><b>📦Компоненты системы</b></summary>

---

### 🏗️1. Terraform (01-terraform)

**Назначение:** Создание и управление инфраструктурой виртуальных машин

**Основные функции:**
- Создание виртуальных машин в Proxmox VE с использованием cloud-init
- Генерация Ansible inventory на основе созданных VM
- Автоматическое копирование конфигурационных файлов на целевые хосты
- Управление сетевыми настройками и ресурсами VM

**Входные данные:**
- Конфигурация виртуальных машин (количество, ресурсы, IP-адреса)
- Параметры подключения к Proxmox (endpoint, API токен)
- Сетевые параметры (gateway, CIDR, bridge)

**Выходные данные:**
- Созданные виртуальные машины в Proxmox
- Ansible inventory файл (`02-ansible/inventory/prod/hosts.yaml`)
- Скопированные файлы на Ansible Control VM
- Скопированные ArgoCD Applications на Kubernetes control plane

**Архитектурные особенности:**
- Модульная структура для переиспользования конфигураций
- Использование шаблонов для генерации конфигураций
- Автоматизация передачи данных между этапами развертывания

---

### 🔧2. Ansible (02-ansible)

**Назначение:** Конфигурация и развертывание Kubernetes кластера

**Основные функции:**
- Базовая настройка всех узлов кластера
- Инициализация Kubernetes control plane
- Присоединение worker nodes к кластеру
- Установка сетевого плагина (CNI)
- Развертывание инфраструктурных компонентов (Helm, Ingress Controller, ArgoCD)
- Установка мониторинга на Proxmox хосты

**Входные данные:**
- Ansible inventory (генерируется Terraform)
- Playbooks и roles для различных компонентов
- Переменные конфигурации (версии, домены, сетевые параметры)

**Выходные данные:**
- Полностью настроенный Kubernetes кластер
- Установленные инфраструктурные компоненты
- Готовый к работе ArgoCD для управления приложениями

**Архитектурные особенности:**
- Разделение логики на roles для переиспользования
- Playbooks как оркестраторы, объединяющие roles
- Конфигурация через переменные в group_vars
- Идемпотентность операций

---

### 📦3. ArgoCD Applications (03-argocd)

**Назначение:** Управление приложениями в Kubernetes кластере через GitOps

**Основные функции:**
- Декларативное определение приложений через Application манифесты
- Автоматическая синхронизация состояния приложений
- Управление зависимостями между приложениями
- Self-healing (автоматическое восстановление желаемого состояния)

**Входные данные:**
- Application манифесты для каждого приложения
- Helm charts или Kustomize конфигурации
- Параметры развертывания (values, переменные)

**Выходные данные:**
- Работающие приложения в Kubernetes кластере
- Автоматически управляемые сертификаты TLS
- Мониторинг и алертинг
- CI/CD платформы и инструменты управления

**Архитектурные особенности:**
- GitOps подход: состояние в Git = состояние в кластере
- Автоматическая синхронизация и самовосстановление
- Поддержка различных источников (Helm, Kustomize)
- Централизованное управление TLS через cert-manager

</details>

---

<details>
<summary><b>🔄Жизненный цикл развертывания</b></summary>

---

Процесс развертывания проходит через последовательные этапы, где каждый этап подготавливает основу для следующего.

### 🗺️Этапы развертывания

---

#### 🏗️Этап 1: Создание инфраструктуры (Terraform)
- Определение конфигурации VM в `01-terraform/proxmox/vm-ubuntu/live/terraform.tfvars`
- Выполнение `terraform apply`
- Создание виртуальных машин в Proxmox
- Автоматическая настройка через cloud-init
- Генерация и копирование конфигурационных файлов

---

#### ☸️Этап 2: Конфигурация кластера (Ansible)
- Подключение к Ansible Control VM
- Выполнение playbooks для настройки узлов
- Инициализация Kubernetes control plane
- Установка сетевого плагина
- Присоединение worker nodes
- Развертывание инфраструктурных компонентов

---

#### 📦Этап 3: Развертывание приложений (ArgoCD)
- Применение ArgoCD Application манифестов
- Автоматическое развертывание cert-manager (первым)
- Развертывание остальных приложений
- Автоматическая настройка TLS сертификатов
- Мониторинг состояния через ArgoCD UI

</details>

---

<details>
<summary><b>📁Структура проекта</b></summary>

---

Проект организован в три основные директории, каждая из которых отвечает за свой этап развертывания:

```
lab-home/
├── 01-terraform/          # Создание инфраструктуры
│   └── proxmox/           # Провайдер Proxmox
│       └── vm-ubuntu/     # Конфигурация для Ubuntu VM
│           ├── live/     # Конфигурация для конкретного окружения
│           │   ├── main.tf        # Основная конфигурация
│           │   ├── variables.tf   # Определение переменных
│           │   ├── scripts/       # Скрипты копирования файлов
│           │   └── templates/     # Шаблоны для генерации конфигураций
│           └── modules/           # Переиспользуемые Terraform модули
│               └── base-vm-cloudinit/  # Модуль создания VM с cloud-init
│
├── 02-ansible/            # Конфигурация и развертывание
│   ├── inventory/         # Inventory файлы по окружениям
│   │   └── prod/          # Production окружение
│   │       ├── hosts.yaml # Генерируется Terraform
│   │       └── group_vars/# Переменные для групп хостов
│   ├── playbooks/         # Ansible playbooks
│   │   ├── site.yml       # Главный playbook
│   │   ├── k8s/           # Kubernetes развертывание
│   │   ├── helm/          # Установка Helm
│   │   ├── ingress-nginx/ # Ingress контроллер
│   │   └── argocd/        # ArgoCD развертывание
│   └── roles/             # Ansible roles (логика компонентов)
│
└── 03-argocd/            # Управление приложениями
    ├── cert-manager/     # TLS сертификаты
    ├── gitlab/           # GitLab CI/CD
    ├── homepage/         # Дашборд
    ├── media-server-stack/  # Медиа-серверы
    │   ├── jellyfin/     # Медиасервер
    │   ├── prowlarr/     # Индексер
    │   ├── qbittorrent/  # Торрент-клиент
    │   └── radarr/       # Управление фильмами
    ├── minio/            # S3-совместимое хранилище
    ├── n8n/              # Автоматизация workflow
    ├── prometheus-stack/ # Мониторинг
    └── rancher/          # Управление кластерами
```

### 📁Логическая организация

1. **01-terraform/** — инфраструктурный слой
   - Создание виртуальных машин
   - Подготовка среды для конфигурации
   - Генерация конфигурационных файлов

2. **02-ansible/** — конфигурационный слой
   - Настройка операционной системы
   - Развертывание Kubernetes
   - Установка инфраструктурных компонентов

3. **03-argocd/** — прикладной слой
   - Определение приложений
   - Управление жизненным циклом
   - Автоматизация развертывания

</details>

---

<details>
<summary><b>⚡Автоматизация передачи данных</b></summary>

---

1. **Terraform → Ansible**
   - Автоматическая генерация inventory на основе созданных VM
   - Копирование playbooks, roles и переменных через скрипт `push_ansible_files.sh`
   - Настройка структуры директорий на Ansible Control VM

2. **Terraform → Kubernetes**
   - Копирование ArgoCD Application манифестов на control plane через скрипт `push_argocd_applications.sh`
   - Подготовка файлов для последующего применения через kubectl

3. **Ansible → Kubernetes**
   - Применение конфигураций через kubectl и Helm
   - Установка компонентов кластера
   - Настройка сетевых и системных параметров

4. **ArgoCD → Приложения**
   - Чтение Application манифестов из Git или файловой системы
   - Автоматическая синхронизация состояния приложений
   - Управление зависимостями между приложениями

</details>

---
---
---

<details>
<summary><b>☸️Talos Linux — иной вариант установки</b></summary>

---

```mermaid
graph LR
    subgraph L1 [1. Инфраструктура]
        T[Terraform<br/>IaC]
        P[Proxmox VE<br/>VM Talos]
    end
    subgraph L2 [2. Кластер]
        Tal[Talos<br/>bootstrap]
        K[Kubernetes<br/>Flannel CNI]
    end
    subgraph L3 [3. GitOps и приложения]
        A[Argo CD<br/>Helm]
        App[Приложения<br/>03-argocd]
    end
    T -->|Создает VM| P
    P --> Tal
    Tal -->|Поднимает| K
    K -->|Хостит| A
    A -->|Синхр. из Git| App
```

Используется директория **01-terraform/proxmox/vm-talos** 

**Ansible не используется** - кластер поднимается средствами Terraform и Talos (bootstrap)

Приложения из 03-argocd можно подтянуть из Git.

**Скрипт `start.sh`** (запуск из `01-terraform/proxmox/vm-talos`):

1. Проверяет наличие `terraform.tfvars`, переменной `talos_image_file_id` и инструментов (terraform, helm, kubectl).
2. Выполняет `terraform init`, `terraform plan` и после подтверждения — `terraform apply` (создание VM Talos в Proxmox, применение конфигурации Talos, bootstrap кластера).
3. По желанию сохраняет kubeconfig в `~/.kube/<talos_cluster_name>.yaml` и ждёт готовности кластера (до ~5 мин).
4. Устанавливает **Argo CD** из локального чарта (`fetched/argo-cd-*.tgz`) с values из `platform/argocd/values.yaml`.
5. Устанавливает **NGINX Ingress Controller** из локального чарта с values из `platform/ingress-nginx/values.yaml` (NodePort 30080/30443).
6. Выводит сводку: IP нод, URL и пароль Argo CD.

- **Образ Talos:** скачать `./scripts/fetch/fetch-talos.sh`, загрузить полученный образ в Proxmox и указать `talos_image_file_id` в `terraform.tfvars`.

- **Чарты Argo CD и Ingress**: `./scripts/fetch/fetch-argocd.sh` и `./scripts/fetch/fetch-ingress-nginx.sh`.

- Манифесты 03-argocd на ноды не копируются: в Argo CD создаёте Application(s) на репозиторий и путь `03-argocd` или `03-argocd/<приложение>`.

Подробнее: [01-terraform/proxmox/vm-talos/README.md](01-terraform/proxmox/vm-talos/README.md).

</details>

---