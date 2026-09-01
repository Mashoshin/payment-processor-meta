#!/usr/bin/env bash
# Сквозной smoke-тест платёжного потока. Сервисы должны быть подняты
# (scripts/run-all.sh). Идемпотентен: каждый прогон работает с уникальными
# счетами, поэтому чистить хранилища не нужно и данные не разрушаются.
set -uo pipefail
PAY=http://localhost:8081
LED=http://localhost:8082
NTF=http://localhost:8083
SFX="${RANDOM}${RANDOM}"
FROM="acc_vasya_$SFX"
TO="acc_petya_$SFX"
FAIL=0
echo "Счета прогона: $FROM -> $TO"

check() { # check "описание" "ожидание" "факт"
  if [ "$2" = "$3" ]; then
    echo "  OK   $1"
  else
    echo "  FAIL $1: ожидалось [$2], получено [$3]"
    FAIL=1
  fi
}

echo "1. Health всех сервисов"
for url in "$PAY" "$LED" "$NTF"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$url/health")
  check "health $url" "200" "$code"
done

echo "2. Платёж 1000.00 RUB: $FROM -> $TO"
resp=$(curl -s -w '\n%{http_code}' -X POST "$PAY/payments" \
  -H 'Content-Type: application/json' \
  -d "{\"from\":\"$FROM\",\"to\":\"$TO\",\"amount\":100000}")
code=$(echo "$resp" | tail -1)
body=$(echo "$resp" | sed '$d')
check "код ответа" "201" "$code"
check "status" "completed" "$(echo "$body" | php -r 'echo json_decode(stream_get_contents(STDIN))->status ?? "?";')"
check "notification_sent" "1" "$(echo "$body" | php -r 'echo (int)(json_decode(stream_get_contents(STDIN))->notification_sent ?? 0);')"
pay_id=$(echo "$body" | php -r 'echo json_decode(stream_get_contents(STDIN))->id ?? "";')

echo "3. GET платежа по id"
code=$(curl -s -o /dev/null -w '%{http_code}' "$PAY/payments/$pay_id")
check "GET /payments/$pay_id" "200" "$code"

echo "4. Балансы в ledger"
bal=$(curl -s "$LED/accounts/$TO/balance" | php -r 'echo json_decode(stream_get_contents(STDIN))->balance ?? "?";')
check "баланс $TO" "100000" "$bal"
bal=$(curl -s "$LED/accounts/$FROM/balance" | php -r 'echo json_decode(stream_get_contents(STDIN))->balance ?? "?";')
check "баланс $FROM" "-100000" "$bal"

echo "5. Уведомление у получателя"
cnt=$(curl -s "$NTF/notifications/$TO" | php -r 'echo count(json_decode(stream_get_contents(STDIN))->notifications ?? []);')
check "уведомлений у $TO" "1" "$cnt"

echo "6. Невалидные платежи отклоняются"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$PAY/payments" \
  -H 'Content-Type: application/json' \
  -d "{\"from\":\"$FROM\",\"to\":\"$FROM\",\"amount\":100}")
check "from == to -> 400" "400" "$code"
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$PAY/payments" \
  -H 'Content-Type: application/json' \
  -d "{\"from\":\"$FROM\",\"to\":\"$TO\",\"amount\":0}")
check "amount 0 -> 400" "400" "$code"

echo
if [ "$FAIL" = "0" ]; then
  echo "SMOKE: GREEN"
else
  echo "SMOKE: RED"
  exit 1
fi
