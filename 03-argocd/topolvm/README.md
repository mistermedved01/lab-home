# TopolVM (StorageClass для LVM-томов)

`TopolVM` — CSI-драйвер для Kubernetes, который предоставляет динамическое PVC-хранилище на базе LVM локально на нодах. По умолчанию используется StorageClass `topolvm-provisioner`

<details>
<summary><strong>⚙️Установка</strong></summary>

---

### 1. LVM на нодах

На каждой worker-ноде, где нужны тома TopolVM, выполнить:

```bash
sudo pvcreate /dev/sdb
sudo vgcreate vg_ssd1 /dev/sdb
```

Пример:

```bash
lsblk
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda       8:0    0   10G  0 disk
├─sda1    8:1    0    9G  0 part /
├─sda14   8:14   0    4M  0 part
├─sda15   8:15   0  106M  0 part /boot/efi
└─sda16 259:0    0  913M  0 part /boot
sdb       8:16   0   30G  0 disk
sr0      11:0    1    4M  0 rom

sudo pvcreate /dev/sdb
  Physical volume "/dev/sdb" successfully created.

sudo vgcreate vg_ssd1 /dev/sdb
  Volume group "vg_ssd1" successfully created
```

Имя VG должно совпадать с `lvmd.deviceClasses[].volume-group` в values (по умолчанию `vg_ssd1`)

### 2. Namespace и метки

```bash
kubectl create namespace topolvm-system --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace topolvm-system topolvm.io/webhook=ignore
kubectl label namespace kube-system topolvm.io/webhook=ignore
```

### 3. Установка Helm-чарта

```bash
helm upgrade --install topolvm ./03-argocd/topolvm/helm/charts/topolvm -n topolvm-system -f 03-argocd/topolvm/helm/custom-values/lab-home.yaml
```

Чарт может подтянуть cert-manager как зависимость; при необходимости установите cert-manager заранее.

</details>

<details>
<summary><strong>📋Описание и компоненты</strong></summary>

---

TopolVM — CSI-драйвер, который по запросу создаёт в кластере LV (логические тома LVM) на нодах и привязывает их к PV. Каждый PVC = один LV в указанной VG на одной ноде (ReadWriteOnce).

### Кратко: LVM и Kubernetes

- **LVM:** диск → PV → VG (пул) → LV (том) → файловая система. На каждой ноде своя VG (например `vg_ssd1` на `/dev/sdb`); пулы между нодами не объединяются.
- **Kubernetes:** приложение запрашивает том через PVC и StorageClass. CSI-драйвер создаёт реальный том и сообщает планировщику, на каких нодах есть свободное место (CSIStorageCapacity). Планировщик ставит под с PVC на ноду, где создан том.

### Компоненты TopolVM

- **topolvm-controller** — создаёт PV, обновляет CSIStorageCapacity по нодам, отдаёт команды lvmd.
- **lvmd** (DaemonSet) — на каждой ноде общается с локальной VG (`vg_ssd1`), по запросу создаёт LV и форматирует (xfs).
- **topolvm-node** (DaemonSet) — CSI node plugin, монтирует тома в поды.

### Основные параметры

- **Namespace:** `topolvm-system`
- **StorageClass:** `topolvm-provisioner` (volumeBindingMode: WaitForFirstConsumer, allowVolumeExpansion: true)
- **Values:** `03-argocd/topolvm/helm/custom-values/lab-home.yaml` — device class `default`, VG `vg_ssd1`, `spare-gb: 2`
- **spare-gb** — объём в гигабайтах, который **не отдаётся** под PVC и остаётся зарезервированным на ноде. Доступная ёмкость в API = max(0, VFree в VG − spare-gb). Нужен запас под метаданные LVM и непредвиденный рост; в проде обычно 1–2G, при 0 — вся VFree отдаётся в планировщик.

</details>

<details>
<summary><strong>📋Структура файлов</strong></summary>

---

```
03-argocd/topolvm/
├── README.md
├── pvc-audit-topolvm-by-node.sh   # Аудит PVC на ноде (все StorageClass) + capacity TopolVM
└── helm/
    ├── charts/
    │   └── topolvm/               # Локальная копия Helm chart TopolVM
    └── custom-values/
        └── lab-home.yaml          # Values для VG vg_ssd1 и spare-gb: 2 (полный device class)
```

</details>

<details>
<summary><strong>📋Требования</strong></summary>

---

1. **cert-manager** в кластере (TopolVM использует webhook)
2. На **каждой worker-ноде**, где будут тома:
   - пакет `lvm2`;
   - свободный диск или раздел под LVM;
   - созданная **volume group** (имя должно совпадать с `lvmd.deviceClasses[].volume-group` в values, по умолчанию `vg_ssd1`).

</details>

<details>
<summary><strong>🔍Проверка и эксплуатация</strong></summary>

---

### Поды и StorageClass

```bash
kubectl get storageclass
kubectl get pods -n topolvm-system
kubectl get csidriver
```

### Доступное место по нодам

Имена нод и capacity:

```bash
kubectl get csistoragecapacity -n topolvm-system -o go-template='{{printf "NODE\tCAPACITY\n"}}{{range .items}}{{index .nodeTopology.matchLabels "topology.topolvm.io/node"}}{{"\t"}}{{.capacity}}{{"\n"}}{{end}}'
```

### Аудит PVC (TopolVM) по ноде

Для аудита PVC на конкретной ноде используйте скрипт из этого каталога: он показывает PVC подов на выбранной ноде по всем StorageClass (включая TopolVM), суммарный запрошенный объём по каждому StorageClass и доступную TopolVM capacity этой ноды.

```bash
./03-argocd/topolvm/pvc-audit-topolvm-by-node.sh k8s-worker-01
```

Вывод: доступно на ноде (CSIStorageCapacity), таблица Namespace / PVC / Size, сумма запрошенного (Gi). Size — из `spec.resources.requests.storage`, не фактическое занятие на диске.

</details>