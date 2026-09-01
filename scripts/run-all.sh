#!/usr/bin/env bash
# Поднимает все сервисы из workspace/ (main-копии). Пиды — в workspace/.pids.
# Источник правды о топологии — манифесты registry/*.md: из пар name/port
# собираются переменные <NAME>_URL и передаются каждому сервису при старте,
# перекрывая дефолты, зашитые в коде сервисов.
set -euo pipefail
META_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$META_DIR"
PIDS_FILE="workspace/.pids"
: > "$PIDS_FILE"

# Первый проход: собрать имена, порты и переменные топологии
NAMES=()
PORTS=()
TOPOLOGY_ENV=()
for manifest in registry/*.md; do
  name="$(grep -m1 '^name:' "$manifest" | sed 's/^name:[[:space:]]*//')"
  port="$(grep -m1 '^port:' "$manifest" | sed 's/^port:[[:space:]]*//')"
  NAMES+=("$name")
  PORTS+=("$port")
  upper="$(echo "$name" | tr '[:lower:]-' '[:upper:]_')"
  TOPOLOGY_ENV+=("${upper}_URL=http://localhost:${port}")
done

# Второй проход: запустить каждый сервис с полной топологией в окружении
for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"
  port="${PORTS[$i]}"
  dir="workspace/$name"
  [ -d "$dir" ] || { echo "[$name] нет в workspace/ — сначала scripts/bootstrap.sh" >&2; exit 1; }
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "[$name] ОШИБКА: порт $port уже занят" >&2; exit 1
  fi
  # exec — чтобы php унаследовал pid subshell и stop-all убивал именно его
  (cd "$dir" && exec env "${TOPOLOGY_ENV[@]}" php -S "localhost:$port" public/index.php >/dev/null 2>&1) &
  echo "$name $!" >> "$META_DIR/$PIDS_FILE"
  echo "[$name] запущен на :$port (pid $!)"
done

echo "Топология: ${TOPOLOGY_ENV[*]}"

sleep 1
for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"
  port="${PORTS[$i]}"
  if curl -sf "http://localhost:$port/health" >/dev/null; then
    echo "[$name] health OK"
  else
    echo "[$name] health FAIL" >&2
  fi
done
