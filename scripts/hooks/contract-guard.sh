#!/usr/bin/env bash
# PreToolUse-хук: блокирует правку contracts/*, если ни один тикет
# в tickets/in-progress/ не заявляет изменение этого контракта.
# Exit 2 = заблокировать вызов инструмента (stderr увидит агент).
set -uo pipefail
INPUT="$(cat)"

FILE_PATH="$(echo "$INPUT" | php -r '
  $d = json_decode(stream_get_contents(STDIN), true);
  echo $d["tool_input"]["file_path"] ?? "";
')"

case "$FILE_PATH" in
  */contracts/*) ;;
  *) exit 0 ;;
esac

META_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SERVICE="$(basename "$FILE_PATH" | sed 's/\.openapi\.yaml$//')"

if ls "$META_DIR"/tickets/in-progress/*.md >/dev/null 2>&1 \
   && grep -l "$SERVICE" "$META_DIR"/tickets/in-progress/*.md >/dev/null 2>&1; then
  exit 0
fi

echo "БЛОК: правка контракта '$SERVICE' без тикета. Contract-first: заведи тикет," >&2
echo "заполни секцию «Изменения контрактов», перенеси в tickets/in-progress/ — и только потом правь контракт." >&2
exit 2
