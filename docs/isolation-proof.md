# Доказательство изоляции агента (Docker)

Дата: 2026-09-01. Образ `metarepo-agent` (см. `Dockerfile`), запуск через
`scripts/claude-docker.sh`. В контейнер смонтирована **только мета** (`/work`).

## Окружение внутри контейнера

```
PHP 8.4.25 (cli) · git 2.39.5 · gh 2.98.0 · node v22.23.2 · Claude Code 2.1.257
whoami → agent (не root) · pwd → /work
```

## Попытки выйти за границу — вывод отказов

Попытка прочитать ssh-ключи хоста:

```
$ cat /Users/e.mashoshin/.ssh/id_rsa
cat: /Users/e.mashoshin/.ssh/id_rsa: No such file or directory
```

Попытка увидеть соседние проекты хоста:

```
$ ls /Users/e.mashoshin/Development
ls: cannot access '/Users/e.mashoshin/Development': No such file or directory
```

Попытка добраться до конфигурации Claude на хосте:

```
$ ls /Users/e.mashoshin/.claude
ls: cannot access '/Users/e.mashoshin/.claude': No such file or directory
```

Корень контейнера — стандартный Debian, никаких следов файловой системы хоста:

```
$ ls /
bin boot dev etc home lib media mnt opt proc root run sbin srv sys tmp usr var work
```

## Вывод

Отказ — на уровне файловой системы (`No such file or directory`), а не
на уровне «агент вежливо не стал»: путей хоста в контейнере физически
не существует. Граница дополнительно сужена кредами: `GH_TOKEN`
выпускается fine-grained только на 4 репозитория системы.

## Известное ограничение (проверено на занятии, применимо и здесь)

MCP-серверы, запущенные **на хосте** и проброшенные агенту, работают вне
этой границы и могут стать тоннелем наружу. Правило меты: MCP-серверы
запускаются только внутри контейнера.
