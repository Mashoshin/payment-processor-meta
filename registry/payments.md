---
name: payments
repo: https://github.com/Mashoshin/payments-api.git
port: 8081
depends_on: [ledger, notifications]
contract: contracts/payments.openapi.yaml
run: php -S localhost:8081 public/index.php
---

# payments

Оркестратор платёжного потока: принимает платёж, синхронно создаёт проводку
в ledger, затем best-effort отправляет уведомление получателю через notifications.

- Хранение: `var/storage.json` (платежи со статусами `pending|completed|failed`).
- Конфигурация: `LEDGER_URL` (default `http://localhost:8082`),
  `NOTIFICATIONS_URL` (default `http://localhost:8083`).
- Владелец: команда payments (в демо — агент №1).
