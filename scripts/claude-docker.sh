#!/usr/bin/env bash
# Запуск изолированного агента Claude Code в Docker.
# Монтируется ТОЛЬКО метарепозиторий: файлов хоста в контейнере не существует.
#
#   scripts/claude-docker.sh                  # собрать (при необходимости) и запустить claude
#   scripts/claude-docker.sh --build          # пересобрать образ принудительно
#   scripts/claude-docker.sh bash             # шелл внутри контейнера вместо claude
#   Аргументы после флагов передаются как команда контейнера.
#
# Аутентификация Claude (достаточно одного из вариантов):
#   CLAUDE_CODE_OAUTH_TOKEN — токен подписки Pro/Max: получить на хосте
#                             командой `claude setup-token` (рекомендуется)
#   ANTHROPIC_API_KEY       — ключ API (биллинг по API)
#   ничего                  — интерактивный /login внутри контейнера;
#                             логин, тема и онбординг переживают перезапуски
#                             в именованном томе metarepo-agent-home
#                             (весь /home/agent: ~/.claude И ~/.claude.json)
# Прочее окружение:
#   GH_TOKEN           — fine-grained токен ТОЛЬКО на репозитории системы
#   GIT_USER_NAME / GIT_USER_EMAIL — идентичность коммитов агента
set -euo pipefail
META_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE=metarepo-agent

FORCE_BUILD=0
if [ "${1:-}" = "--build" ]; then FORCE_BUILD=1; shift; fi

if [ "$FORCE_BUILD" = "1" ] || ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Собираю образ $IMAGE..."
  docker build -t "$IMAGE" "$META_DIR"
fi

exec docker run -it --rm \
  -v "$META_DIR:/work" \
  -v metarepo-agent-home:/home/agent \
  -e CLAUDE_CODE_OAUTH_TOKEN \
  -e ANTHROPIC_API_KEY \
  -e GH_TOKEN \
  -e GIT_USER_NAME \
  -e GIT_USER_EMAIL \
  "$IMAGE" "$@"
