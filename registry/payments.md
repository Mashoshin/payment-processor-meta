---
name: payments
repo: https://github.com/Mashoshin/payments-api.git
port: 8081
depends_on: [ledger, notifications]
contract: contracts/payments.openapi.yaml
run: php -S localhost:8081 public/index.php
---

# payments

Оркестратор платёжного потока: принимает платёж, считает комиссию, синхронно
кладёт в ledger **две** проводки одним атомарным запросом (перевод `from -> to`
и комиссионное плечо `from -> acc_fee`), затем best-effort отправляет
уведомление получателю через notifications. С отправителя списывается
`amount + fee`, получателю приходит ровно `amount`.

- Идемпотентность: ключ — пара `(from, client_oid)`, `client_oid` обязателен.
  Точный повтор → `200` и тот же платёж (ничего не списывается), тот же ключ
  с другими `to`/`amount` → `409`. Подробности — в `map.md`, раздел
  «Повторы и идемпотентность».
- Хранение: `var/storage.json` (платежи со статусами `pending|completed|failed`).
- Конфигурация: `LEDGER_URL` (default `http://localhost:8082`),
  `NOTIFICATIONS_URL` (default `http://localhost:8083`).
- Владелец: команда payments (в демо — агент №1).
