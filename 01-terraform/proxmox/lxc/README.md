# Proxmox LXC (Terraform)

Базовое создание **LXC** через провайдер [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest) — один переиспользуемый модуль и каталог `live/` со списком контейнеров (по аналогии с `vm-ubuntu`).

## Структура

| Путь | Назначение |
|------|------------|
| [`modules/base-lxc/`](modules/base-lxc/) | Ресурс `proxmox_virtual_environment_container`: шаблон, rootfs, CPU/RAM, сеть, SSH-ключи root |
| [`live/`](live/) | Провайдеры для трёх нод (`pve-node-01` … `03`) и `lxc_list` |

## Быстрый старт

1. Загрузите в Proxmox **шаблон** CT (Ubuntu/Debian и т.д.) — тот же storage, что используете в `template_file_id`. Откуда берутся каталоги образов, прямые URL `download.proxmox.com` и `pveam`: см. **[`proxmox-container-urls.md`](proxmox-container-urls.md)**.
2. Узнайте точное имя файла шаблона, например:

   ```bash
   pvesm list local --content vztmpl
   ```

   Формат для Terraform: `storage:volid`, чаще всего `local:vztmpl/имя-файла.tar.zst`.

3. В `live/`:

   ```bash
   cd live
   cp terraform.tfvars.example terraform.tfvars
   # заполните proxmox_nodes, ssh_public_key, lxc_list, template_file_id
   terraform init
   terraform plan
   terraform apply
   ```

4. Поле **`node_name`** внутри `proxmox_nodes` должно совпадать с именем узла в PVE (как в `pvecm status` / веб-интерфейсе), а не обязательно с ключом `pve-node-01` в map.

## Переменные CT (`lxc_list`)

- **`proxmox_node`** — одно из: `pve-node-01`, `pve-node-02`, `pve-node-03` (те же ключи, что в `proxmox_nodes`).
- **`template_file_id`** — обязательно; без корректного шаблона apply упадёт.
- **`network_interface`** — по умолчанию `eth0`; если после создания нет IP, проверьте имя интерфейса для вашего шаблона (редко `veth0`).

Опции **`nesting`**, **`unprivileged`**, отдельный **`dns_servers_override`** на CT — см. `live/variables.tf`.

## Ограничения провайдера

- Массовое параллельное создание CT на одном storаge может давать lock-ошибки PVE — при необходимости `-parallelism=1`.
- CT под HA-кластером PVE возможны расхождения state — см. README провайдера.

### Feature flags и API-токен (`terraform@pve` и т.п.)

Через API обычно работает так:

- Токен вида **`terraform@pve!...`**: Proxmox часто разрешает менять только **`nesting`**. Для **`fuse`**, **`keyctl`**, привилегированного CT возможен ответ:

  `Permission check failed (changing feature flags (except nesting) is only allowed for root@pam)`

- Токен **`root@pam!...`**: иногда **`fuse` / `keyctl`** через API всё равно не проходят (см. ниже).

**Если `403 Permission check failed` без подробностей при создании CT:**

- В **Datacenter → Permissions → API Tokens** откройте токен и снимите **Privilege Separation** (или создайте токен без разделения привилегий) — иначе многие операции с CT отклоняются.
- Убедитесь, что у пользователя/токена есть права на **VM/CT** и на нужную **ноду** / **пул**.
- Практичный обход: в Terraform только **`nesting = true`**, без **`fuse` / `keyctl`**; после создания CT в UI: **Options → Features → FUSE, Keyctl**.

**Если 403 только на fuse/keyctl:**

1. Создать CT с **`nesting = true`** без fuse/keyctl в `lxc_list`.
2. В **веб-интерфейсе Proxmox**: CT → **Options** → **Features** → **FUSE** / **Keyctl**, перезагрузка CT.
3. Либо **пароль `root@pam`** в провайдере вместо `api_token` (не коммитить).

### Privileged LXC (`unprivileged = false`) и API-токен

Аналогично: привилегированный CT и часть флагов — только `root@pam` (часто только с паролем, не с токеном).

Варианты:

1. **`unprivileged = true`** + **`nesting = true`** через Terraform; **fuse/keyctl** — в UI после создания.
2. **Пароль `root@pam`** в провайдере вместо `api_token` — если нужны все флаги из Terraform или privileged CT.
3. Создать CT вручную в UI/`pct`, затем `terraform import` или оставить вне Terraform.

## Docker в LXC и ошибка overlay (`permission denied`)

Если в **unprivileged** CT при `docker compose up` / pull падает распаковка слоя:

`failed to mount ... fstype: overlay ... permission denied` (часто с `userxattr`),

то containerd не может собрать overlay внутри пользовательского namespace LXC.

**Что сделать (по приоритету):**

1. В Terraform: **`nesting = true`**. Флаги **`fuse` / `keyctl`** через токен `terraform@pve` в PVE задать нельзя — после `apply` включите их в **веб-интерфейсе** Proxmox (Options → Features), затем перезагрузите CT. См. раздел «Feature flags и API-токен» выше.
2. **Надёжно для Docker** — **privileged** CT (`unprivileged = false`): см. раздел выше (часто нужен пароль root@pam, не токен).
3. **Быстрый обход без смены CT** (медленно, больше места на диске): внутри CT задать драйвер хранилища без overlay:

   ```json
   /etc/docker/daemon.json
   { "storage-driver": "vfs" }
   ```

   затем `systemctl restart docker` и снова `docker compose up -d`.

Предупреждение Compose про устаревший ключ `version` в `docker-compose.yml` можно убрать, удалив строку `version:` из файла.

## Связь с Zabbix / Ansible

После `apply` возьмите IP из `terraform output` и установите Zabbix в CT вручную или через Docker — см. [`../zabbix-lxc/README.md`](../zabbix-lxc/README.md).
