# Модуль base-lxc

Оборачивает ресурс **`proxmox_virtual_environment_container`**: один LXC с статическим IPv4, rootfs на выбранном `datastore_id`, SSH-ключами для `root`.

Переменные — в [`variables.tf`](variables.tf). Требуется передать `template_file_id` в формате `datastore:path` (см. `pvesm list <storage> --content vztmpl`).
