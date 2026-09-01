---
name: notifications
repo: https://github.com/Mashoshin/notifications-api.git
port: 8083
depends_on: []
contract: contracts/notifications.openapi.yaml
run: php -S localhost:8083 public/index.php
---

# notifications

Приём и хранение уведомлений по счетам, лента уведомлений. Ничего не знает
про платежи и проводки — только счёт и текст сообщения. Никого не вызывает.

- Хранение: `var/storage.json` (массив уведомлений).
- Владелец: команда notifications (в демо — агент №3).
