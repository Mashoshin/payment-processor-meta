---
name: ledger
repo: https://github.com/Mashoshin/ledger-api.git
port: 8082
depends_on: []
contract: contracts/ledger.openapi.yaml
run: php -S localhost:8082 public/index.php
---

# ledger

Журнал проводок (двойная запись). Единственный источник правды о движении денег.
Проводки только дописываются; баланс счёта вычисляется из журнала.
Никого не вызывает, ни о ком не знает.

- Хранение: `var/storage.json` (массив проводок).
- Владелец: команда ledger (в демо — агент №2).
