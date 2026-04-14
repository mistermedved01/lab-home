#!/bin/bash
# Аудит PVC на ноде: все StorageClass + доступная capacity TopolVM для этой ноды.
# Запуск: pvc-audit-topolvm-by-node.sh <node-name> [topolvm-namespace]
#        или TOPOLVM_NS=nativestor-system pvc-audit-topolvm-by-node.sh <node-name>
# По умолчанию namespace TopolVM — topolvm-system; в некоторых кластерах — nativestor-system.
#
# Выводит:
#   - доступную capacity TopolVM на ноде (CSIStorageCapacity);
#   - таблицу всех PVC, чьи поды на ноде: Namespace, PVC, Size, STORAGECLASS;
#   - сумму запрошенного объёма по каждому StorageClass (размеры в Gi)

set -e
NODE="$1"

# Namespace TopolVM можно переопределить переменной TOPOLVM_NS или вторым аргументом
NS_TOPOLVM="${TOPOLVM_NS:-${2:-topolvm-system}}"

VOLSTATS_FILE=""
if [ -n "$NODE" ]; then
  tmpfile="$(mktemp)"
  set +e
  kubectl get --raw "/api/v1/nodes/${NODE}/proxy/stats/summary" 2>/dev/null \
    | python3 - <<'PY' >"$tmpfile"
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)

pods = data.get("pods") or []
for pod in pods:
    for vs in pod.get("volumeStats") or []:
        pvc = vs.get("pvcRef") or {}
        ns = pvc.get("namespace")
        name = pvc.get("name")
        if not ns or not name:
            continue
        used = vs.get("usedBytes")
        cap_ = vs.get("capacityBytes")
        if used is None or cap_ is None:
            continue
        print(f"{ns}\t{name}\t{used}\t{cap_}")
PY
  rc=$?
  set -e
  if [ "$rc" -eq 0 ] && [ -s "$tmpfile" ]; then
    VOLSTATS_FILE="$tmpfile"
  else
    rm -f "$tmpfile"
  fi
fi

echo "=== Аудит PVC на ноде: $NODE ==="
echo

# Capacity TopolVM на ноде
CAPACITY=$(kubectl get csistoragecapacity -n "$NS_TOPOLVM" -o go-template='{{range .items}}{{if eq (index .nodeTopology.matchLabels "topology.topolvm.io/node") "'"$NODE"'"}}{{.capacity}}{{end}}{{end}}' 2>/dev/null)
echo "Доступно на ноде (TopolVM, CSIStorageCapacity): ${CAPACITY:-—}"
echo

if [ -z "$VOLSTATS_FILE" ]; then
  echo "Метрики фактического использования PVC с ноды получить не удалось (нет доступа к stats/summary)"
  echo "Будут показаны только запрошенные объёмы."
  echo
fi

# Таблица: все PVC на ноде (Namespace, PVC, Requested, UsedGi, Used%, STORAGECLASS)
printf "%-20s %-40s %8s %10s %7s %-20s\n" "Namespace" "PVC" "Req" "UsedGi" "Used%" "STORAGECLASS"

kubectl get pods -A --field-selector spec.nodeName="$NODE" \
  -o go-template='{{range .items}}{{$ns := .metadata.namespace}}{{range .spec.volumes}}{{if .persistentVolumeClaim}}{{$ns}}{{"\t"}}{{.persistentVolumeClaim.claimName}}{{"\n"}}{{end}}{{end}}{{end}}' \
  | sort -u \
  | while read -r ns pvc; do
      size=$(kubectl get pvc "$pvc" -n "$ns" -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)
      sc=$(kubectl get pvc "$pvc" -n "$ns" -o jsonpath='{.spec.storageClassName}' 2>/dev/null)

      usedGi="-"
      usedPct="-"
      if [ -n "$VOLSTATS_FILE" ]; then
        line=$(grep -m1 -P "^${ns}\t${pvc}\t" "$VOLSTATS_FILE" 2>/dev/null || true)
        if [ -n "$line" ]; then
          usedBytes=$(echo "$line" | awk '{print $3}')
          capBytes=$(echo "$line" | awk '{print $4}')
          if [ -n "$usedBytes" ] && [ "$usedBytes" -gt 0 ] 2>/dev/null; then
            usedGi=$(awk -v u="$usedBytes" 'BEGIN{printf "%.2f", u/1024/1024/1024}')
          fi
          if [ -n "$capBytes" ] && [ "$capBytes" -gt 0 ] 2>/dev/null; then
            usedPct=$(awk -v u="$usedBytes" -v c="$capBytes" 'BEGIN{printf "%.1f", (c>0)?(u/c*100):0}')
          fi
        fi
      fi

      printf "%-20s %-40s %8s %10s %7s %-20s\n" "$ns" "$pvc" "$size" "$usedGi" "$usedPct" "$sc"
    done | awk '
    {
      print
      sc = $6
      size = $3
      if (size ~ /Gi$/) { gsub(/Gi/, "", size); total[sc] += size + 0 }
    }
    END {
      printf "\n"
      for (s in total) printf "Total for STORAGECLASS %-20s: %d Gi\n", s, total[s]
    }'

if [ -n "$VOLSTATS_FILE" ]; then
  rm -f "$VOLSTATS_FILE"
fi