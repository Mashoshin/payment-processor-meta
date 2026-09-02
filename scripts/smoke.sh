#!/usr/bin/env bash
# Сквозной smoke-тест платёжного потока. Сервисы должны быть подняты
# (scripts/run-all.sh). Идемпотентен: каждый прогон работает с уникальными
# счетами и уникальными client_oid, поэтому чистить хранилища не нужно
# и данные не разрушаются.
set -uo pipefail
PAY=http://localhost:8081
LED=http://localhost:8082
NTF=http://localhost:8083
SFX="${RANDOM}${RANDOM}"
FROM="acc_vasya_$SFX"
TO="acc_petya_$SFX"
FROM2="acc_dave_$SFX"
TO2="acc_masha_$SFX"
OID="order-$SFX"
FAIL=0
echo "Счета прогона: $FROM -> $TO, ключ идемпотентности: $OID"

check() { # check "описание" "ожидание" "факт"
  if [ "$2" = "$3" ]; then
    echo "  OK   $1"
  else
    echo "  FAIL $1: ожидалось [$2], получено [$3]"
    FAIL=1
  fi
}

jget() { # jget <поле> — читает поле json-объекта со stdin
  php -r "\$d = json_decode(stream_get_contents(STDIN)); echo \$d->$1 ?? '?';"
}

pay_code() { # pay_code <json-тело> — код ответа POST /payments
  curl -s -o /dev/null -w '%{http_code}' -X POST "$PAY/payments" \
    -H 'Content-Type: application/json' -d "$1"
}

echo "1. Health всех сервисов"
for url in "$PAY" "$LED" "$NTF"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$url/health")
  check "health $url" "200" "$code"
done

echo "2. Платёж 1000.00 RUB: $FROM -> $TO (комиссия 1% сверху: fee=1000, total=101000)"
# acc_fee — общий системный счёт, накапливается между прогонами. Проверяем
# дельту вокруг платежа, а не абсолютный баланс.
fee_before=$(curl -s "$LED/accounts/acc_fee/balance" | php -r 'echo json_decode(stream_get_contents(STDIN))->balance ?? 0;')
resp=$(curl -s -w '\n%{http_code}' -X POST "$PAY/payments" \
  -H 'Content-Type: application/json' \
  -d "{\"from\":\"$FROM\",\"to\":\"$TO\",\"amount\":100000,\"client_oid\":\"$OID\"}")
code=$(echo "$resp" | tail -1)
body=$(echo "$resp" | sed '$d')
check "код ответа" "201" "$code"
check "status" "completed" "$(echo "$body" | jget status)"
check "fee" "1000" "$(echo "$body" | jget fee)"
check "total" "101000" "$(echo "$body" | jget total)"
check "client_oid в теле" "$OID" "$(echo "$body" | jget client_oid)"
check "notification_sent" "1" "$(echo "$body" | php -r 'echo (int)(json_decode(stream_get_contents(STDIN))->notification_sent ?? 0);')"
pay_id=$(echo "$body" | jget id)

echo "3. GET платежа по id"
resp=$(curl -s -w '\n%{http_code}' "$PAY/payments/$pay_id")
check "GET /payments/$pay_id" "200" "$(echo "$resp" | tail -1)"
check "client_oid в GET" "$OID" "$(echo "$resp" | sed '$d' | jget client_oid)"

echo "4. Балансы в ledger (получатель +amount, отправитель -total, acc_fee +fee)"
bal=$(curl -s "$LED/accounts/$TO/balance" | jget balance)
check "баланс $TO (= amount)" "100000" "$bal"
bal=$(curl -s "$LED/accounts/$FROM/balance" | jget balance)
check "баланс $FROM (= -total)" "-101000" "$bal"
fee_after=$(curl -s "$LED/accounts/acc_fee/balance" | php -r 'echo json_decode(stream_get_contents(STDIN))->balance ?? 0;')
check "дельта acc_fee (= fee)" "1000" "$((fee_after - fee_before))"

echo "5. Уведомление у получателя"
cnt=$(curl -s "$NTF/notifications/$TO" | php -r 'echo count(json_decode(stream_get_contents(STDIN))->notifications ?? []);')
check "уведомлений у $TO" "1" "$cnt"

echo "6. Точный повтор -> 200, тот же платёж, ничего не изменилось"
resp=$(curl -s -w '\n%{http_code}' -X POST "$PAY/payments" \
  -H 'Content-Type: application/json' \
  -d "{\"from\":\"$FROM\",\"to\":\"$TO\",\"amount\":100000,\"client_oid\":\"$OID\"}")
code=$(echo "$resp" | tail -1)
body=$(echo "$resp" | sed '$d')
check "повтор -> 200 (не 201)" "200" "$code"
check "тот же id" "$pay_id" "$(echo "$body" | jget id)"
check "status повтора" "completed" "$(echo "$body" | jget status)"
bal=$(curl -s "$LED/accounts/$FROM/balance")
check "баланс $FROM не изменился" "-101000" "$(echo "$bal" | jget balance)"
check "entries_count $FROM (не удвоился)" "2" "$(echo "$bal" | jget entries_count)"
check "баланс $TO не изменился" "100000" "$(curl -s "$LED/accounts/$TO/balance" | jget balance)"
cnt=$(curl -s "$NTF/notifications/$TO" | php -r 'echo count(json_decode(stream_get_contents(STDIN))->notifications ?? []);')
check "уведомление не продублировалось" "1" "$cnt"

echo "7. Тот же ключ, другие параметры -> 409, денег не уходит"
check "другая сумма -> 409" "409" \
  "$(pay_code "{\"from\":\"$FROM\",\"to\":\"$TO\",\"amount\":50000,\"client_oid\":\"$OID\"}")"
check "другой получатель -> 409" "409" \
  "$(pay_code "{\"from\":\"$FROM\",\"to\":\"$TO2\",\"amount\":100000,\"client_oid\":\"$OID\"}")"
bal=$(curl -s "$LED/accounts/$FROM/balance")
check "баланс $FROM после 409" "-101000" "$(echo "$bal" | jget balance)"
check "entries_count $FROM после 409" "2" "$(echo "$bal" | jget entries_count)"

echo "8. Тот же client_oid от другого отправителя — это другой перевод"
resp=$(curl -s -w '\n%{http_code}' -X POST "$PAY/payments" \
  -H 'Content-Type: application/json' \
  -d "{\"from\":\"$FROM2\",\"to\":\"$TO2\",\"amount\":100000,\"client_oid\":\"$OID\"}")
code=$(echo "$resp" | tail -1)
body=$(echo "$resp" | sed '$d')
check "другой отправитель -> 201" "201" "$code"
check "from в теле" "$FROM2" "$(echo "$body" | jget from)"
other_id=$(echo "$body" | jget id)
if [ "$other_id" != "$pay_id" ] && [ -n "$other_id" ]; then
  echo "  OK   id отличается от платежа $FROM"
else
  echo "  FAIL id не отличается от платежа $FROM: [$other_id]"
  FAIL=1
fi

echo "9. Валидация client_oid"
check "ключа нет -> 400" "400" \
  "$(pay_code "{\"from\":\"$FROM\",\"to\":\"$TO\",\"amount\":100}")"
check "пустой ключ -> 400" "400" \
  "$(pay_code "{\"from\":\"$FROM\",\"to\":\"$TO\",\"amount\":100,\"client_oid\":\"\"}")"
check "недопустимые символы -> 400" "400" \
  "$(pay_code "{\"from\":\"$FROM\",\"to\":\"$TO\",\"amount\":100,\"client_oid\":\"order 42!\"}")"
oid65=$(printf 'a%.0s' $(seq 1 65))
check "65 символов -> 400" "400" \
  "$(pay_code "{\"from\":\"$FROM\",\"to\":\"$TO\",\"amount\":100,\"client_oid\":\"$oid65\"}")"
oid64=$(printf 'b%.0s' $(seq 1 64))
check "ровно 64 символа -> 201" "201" \
  "$(pay_code "{\"from\":\"$FROM\",\"to\":\"$TO\",\"amount\":100,\"client_oid\":\"$oid64\"}")"

echo "10. Журнал не дублирует проводки (прямой POST /entries в ledger)"
PID="pay_smoke_$SFX"
M="acc_m_$SFX"
N="acc_n_$SFX"
entries="[{\"payment_id\":\"$PID\",\"debit\":\"$M\",\"credit\":\"$N\",\"amount\":10000},
          {\"payment_id\":\"$PID\",\"debit\":\"$M\",\"credit\":\"acc_fee\",\"amount\":100}]"
resp=$(curl -s -w '\n%{http_code}' -X POST "$LED/entries" \
  -H 'Content-Type: application/json' -d "$entries")
check "первая запись -> 201" "201" "$(echo "$resp" | tail -1)"
ent_ids=$(echo "$resp" | sed '$d' | php -r '$d=json_decode(stream_get_contents(STDIN),true); echo implode(",", array_column($d ?? [], "id"));')
resp=$(curl -s -w '\n%{http_code}' -X POST "$LED/entries" \
  -H 'Content-Type: application/json' -d "$entries")
check "повтор -> 200" "200" "$(echo "$resp" | tail -1)"
ent_ids2=$(echo "$resp" | sed '$d' | php -r '$d=json_decode(stream_get_contents(STDIN),true); echo implode(",", array_column($d ?? [], "id"));')
check "те же ent_ id" "$ent_ids" "$ent_ids2"
bal=$(curl -s "$LED/accounts/$M/balance")
check "баланс $M (= -total)" "-10100" "$(echo "$bal" | jget balance)"
check "entries_count $M (не удвоился)" "2" "$(echo "$bal" | jget entries_count)"
check "баланс $N (= amount)" "10000" "$(curl -s "$LED/accounts/$N/balance" | jget balance)"
# валидация раньше дедупа: тот же payment_id, но debit == credit -> 400
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$LED/entries" \
  -H 'Content-Type: application/json' \
  -d "[{\"payment_id\":\"$PID\",\"debit\":\"$M\",\"credit\":\"$M\",\"amount\":10000}]")
check "тот же payment_id + невалидное тело -> 400" "400" "$code"

echo "11. Невалидные платежи отклоняются (регресс T-001)"
check "from == to -> 400" "400" \
  "$(pay_code "{\"from\":\"$FROM\",\"to\":\"$FROM\",\"amount\":100,\"client_oid\":\"neg1-$SFX\"}")"
check "amount 0 -> 400" "400" \
  "$(pay_code "{\"from\":\"$FROM\",\"to\":\"$TO\",\"amount\":0,\"client_oid\":\"neg2-$SFX\"}")"

echo
if [ "$FAIL" = "0" ]; then
  echo "SMOKE: GREEN"
else
  echo "SMOKE: RED"
  exit 1
fi
