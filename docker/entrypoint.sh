#!/usr/bin/env bash
# Настройка окружения агента внутри контейнера перед запуском Claude Code.
set -euo pipefail

# Онбординг первого запуска (тема + логин) хранится в ~/.claude.json —
# засеять флаг, чтобы свежий дом не требовал пройти его заново.
if [ ! -s "$HOME/.claude.json" ]; then
  echo '{"hasCompletedOnboarding": true}' > "$HOME/.claude.json"
fi

# git-идентичность для коммитов агента (переопределяется через -e)
git config --global user.name  "${GIT_USER_NAME:-Meta Agent}"
git config --global user.email "${GIT_USER_EMAIL:-agent@metarepo.local}"
git config --global --add safe.directory '*'

# gh: если проброшен GH_TOKEN — научить git пушить по https через него
if [ -n "${GH_TOKEN:-}" ]; then
  gh auth setup-git 2>/dev/null || true
fi

# Пустые auth-переменные хуже отсутствующих: пустой ANTHROPIC_API_KEY имеет
# приоритет над токеном подписки и роняет claude в браузерный логин. Сброс.
[ -n "${ANTHROPIC_API_KEY+x}" ] && [ -z "${ANTHROPIC_API_KEY}" ] && unset ANTHROPIC_API_KEY
[ -n "${CLAUDE_CODE_OAUTH_TOKEN+x}" ] && [ -z "${CLAUDE_CODE_OAUTH_TOKEN}" ] && unset CLAUDE_CODE_OAUTH_TOKEN

if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  echo "auth: токен подписки (${#CLAUDE_CODE_OAUTH_TOKEN} символов)" >&2
elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo "auth: API-ключ (${#ANTHROPIC_API_KEY} символов)" >&2
elif [ -s "$HOME/.claude/.credentials.json" ]; then
  echo "auth: сохранённые креды из тома metarepo-agent-home" >&2
else
  echo "auth: НЕ НАЙДЕНА — передайте CLAUDE_CODE_OAUTH_TOKEN ('claude setup-token'" >&2
  echo "на хосте) или ANTHROPIC_API_KEY, либо выполните /login внутри —" >&2
  echo "креды сохранятся в томе metarepo-agent-home." >&2
fi

exec "$@"
