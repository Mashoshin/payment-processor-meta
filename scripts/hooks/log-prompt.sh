#!/usr/bin/env bash
# UserPromptSubmit-хук: дописывает каждый промпт пользователя дословно
# в sessions/ГГГГ-ММ-ДД.md — журнал сессий собирается механизмом, а не памятью.
# Всегда exit 0: журналирование не должно мешать работе.
set -uo pipefail
INPUT="$(cat)"

prompt="$(echo "$INPUT" | php -r '
  $d = json_decode(stream_get_contents(STDIN), true);
  echo $d["prompt"] ?? "";
')"
sid="$(echo "$INPUT" | php -r '
  $d = json_decode(stream_get_contents(STDIN), true);
  echo substr($d["session_id"] ?? "unknown", 0, 8);
')"

[ -n "$prompt" ] || exit 0

DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/sessions"
mkdir -p "$DIR"
FILE="$DIR/$(date +%F).md"

[ -f "$FILE" ] || echo "# Журнал сессий $(date +%F)" > "$FILE"
{
  echo
  echo "### $(date +%H:%M) · сессия $sid"
  echo '```'
  echo "$prompt"
  echo '```'
} >> "$FILE"

exit 0
