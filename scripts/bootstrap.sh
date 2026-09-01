#!/usr/bin/env bash
# Разворачивает рабочие копии сервисов в workspace/ по манифестам registry/.
# Репозиторий уже в workspace/ — обновляется (pull, если есть origin).
# Репозитория нет — клонируется из repo: манифеста (remote URL).
set -euo pipefail
META_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$META_DIR"

for manifest in registry/*.md; do
  name="$(grep -m1 '^name:' "$manifest" | sed 's/^name:[[:space:]]*//')"
  repo="$(grep -m1 '^repo:' "$manifest" | sed 's/^repo:[[:space:]]*//; s/[[:space:]]*#.*//')"
  dest="workspace/$name"

  if [ -d "$dest/.git" ]; then
    branch="$(git -C "$dest" rev-parse --abbrev-ref HEAD)"
    if git -C "$dest" remote get-url origin >/dev/null 2>&1 \
       && git -C "$dest" pull --ff-only origin "$branch" 2>/dev/null; then
      echo "[$name] обновлён ($dest, $branch)"
    else
      echo "[$name] на месте ($dest), обновление с origin не удалось — работаю с локальной копией"
    fi
  elif [ "$repo" = "TBD" ] || [ -z "$repo" ]; then
    echo "[$name] ОШИБКА: workspace/$name отсутствует, а repo: в $manifest не заполнен" >&2
    exit 1
  else
    echo "[$name] клонирую $repo -> $dest"
    git clone "$repo" "$dest"
  fi
done

echo "Готово. Сервисы в workspace/."
