#!/usr/bin/env bash
# Гасит сервисы, запущенные run-all.sh (по пидам из workspace/.pids).
set -uo pipefail
META_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PIDS_FILE="$META_DIR/workspace/.pids"
[ -f "$PIDS_FILE" ] || { echo "Нечего гасить: $PIDS_FILE нет"; exit 0; }

while read -r name pid; do
  if kill "$pid" 2>/dev/null; then
    echo "[$name] остановлен (pid $pid)"
  else
    echo "[$name] уже не работал (pid $pid)"
  fi
done < "$PIDS_FILE"
rm -f "$PIDS_FILE"
