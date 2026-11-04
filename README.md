# tgsend

Отправка сообщений и файлов через Telegram Bot API из bash.
Без зависимостей кроме `curl` и `jq`. Подходит для cron, CI и любых
автоматизаций: бэкапы, алерты, отчёты.

## Возможности

- текст и файлы до 50 МБ (лимит Bot API)
- длинные сообщения автоматически режутся на части по 4000 символов,
  по возможности не разрывая строки
- `MarkdownV2` и `HTML` — по флагу, по умолчанию текст отправляется как есть
- таймауты, ретраи и корректная обработка `429 Too Many Requests`
  (`retry_after` соблюдается)
- `--dry-run` — проверить, ничего не отправляя
- `--silent`, `--topic` (форумы), `--chat` (получатель на один вызов)
- креды в отдельном файле, а не в скрипте
- лог с ротацией на 1 МБ
- внятные ошибки и коды возврата
- проверка файла перед отправкой: существует, читается, не пустой, в лимите
- `shellcheck`-чистый код

## Требования

- `bash` 4.4+
- `curl`
- `jq`

## Установка

```bash
git clone https://github.com/AdV1PeR/tgsend.git
cd tgsend
chmod +x tgsend.sh
mkdir -p ~/.local/bin
install -m 755 tgsend.sh ~/.local/bin/tgsend
```

Проверка:

```bash
tgsend -v
```

Можно и просто запускать `./tgsend.sh` без установки.

## Настройка

Создайте `~/.config/tgsend/config`:

```bash
TG_BOT_TOKEN="123456789:AA..."
TG_CHAT_ID="123456789"
```

Закройте файл от посторонних:

```bash
chmod 600 ~/.config/tgsend/config
```

Другой путь задаётся через `TG_CONF=/path/to/config`.

Как получить значения:

- токен — у [@BotFather](https://t.me/BotFather) (`/newbot`)
- `chat_id` — написать боту `/start`, затем
  `curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" \
   | jq '.result[0].message.chat.id'`

## Использование

```bash
tgsend -m "Привет"

tgsend -f backup.tar.gz -c "еженедельный бэкап"

tgsend -m "**важно**" -M            # MarkdownV2
tgsend -m "<b>важно</b>" -H         # HTML
tgsend -s -f report.pdf             # без звука
tgsend -t 42 -m "в тему форума"     # message_thread_id
tgsend -C 123456789 -m "другому чату"
tgsend -n -f big.zip -c "проверка"  # dry-run
```

### Флаги

| Флаг | Значение |
|---|---|
| `-m, --message TEXT` | отправить текст (длинный режется на части) |
| `-f, --file FILE` | отправить файл |
| `-c, --caption TEXT` | подпись к файлу |
| `-C, --chat ID` | получатель вместо `TG_CHAT_ID` |
| `-M, --markdown` | `parse_mode=MarkdownV2` |
| `-H, --html` | `parse_mode=HTML` |
| `-s, --silent` | без звука (`disable_notification`) |
| `-t, --topic ID` | `message_thread_id` для форумов |
| `-n, --dry-run` | проверить, ничего не отправляя |
| `-q, --quiet` | без вывода в консоль |
| `-v, --version` | версия |
| `-h, --help` | справка |
| `--` | конец опций |

### Переменные окружения

| Переменная | Значение |
|---|---|
| `TG_BOT_TOKEN` | токен бота |
| `TG_CHAT_ID` | получатель по умолчанию |
| `TG_CAPTION` | подпись к файлу |
| `TG_CONF` | путь к конфигу |
| `TG_MAX_FILE_SIZE` | свой лимит размера файла |

## Автоматизация

Типичный алерт из скрипта или cron — с проверкой результата:

```bash
#!/usr/bin/env bash
set -euo pipefail

if ! systemctl is-active --quiet myservice; then
    tgsend -q -m "🚨 myservice не работает на $(hostname)" || \
        logger -t tgsend "не удалось отправить алерт"
fi
```

Важно: `tgsend` возвращает ненулевой код при ошибке отправки, поэтому
в cron удобно оборачивать вызов в `|| logger ...`. Флаг `-q` убирает
вывод в консоль, но не влияет на код возврата.

## Логи

`~/.local/log/tgsend/tgsend.log` (права 600). Ротация: при 1 МБ файл
становится `tgsend.log.1`. Токен и `chat_id` в лог не пишутся — только
тип операции, размер и имя файла.

## Termux

В Termux нет `/usr/bin/env`, поэтому шебанг `#!/usr/bin/env bash` может
дать `bad interpreter`. Варианты:

```bash
pkg install bash curl jq
bash tgsend.sh -m "test"
```

или заменить первую строку на:

```bash
#!/data/data/com.termux/files/usr/bin/bash
```

## Troubleshooting

| Симптом | Причина и решение |
|---|---|
| `chat not found` | получатель ни разу не нажал `/start` у бота |
| `Unauthorized` | неверный токен в конфиге |
| `429` | слишком часто; скрипт сам ждёт `retry_after` |
| `Request Entity Too Large` | файл больше 50 МБ (лимит Bot API) |
| `bad interpreter` | см. раздел Termux |
| пустой ответ | нет сети или заблокирован `api.telegram.org` |

## Безопасность

- токен хранится только в конфиге с правами 600
- токен не попадает в аргументы командной строки, логи и ошибки
- `--dry-run` не делает сетевых запросов
- скрипт не скачивает и не исполняет ничего извне
- проверка токена идёт через `getMe`, а не `getUpdates` — не конфликтует
  с вебхуком, если он когда-нибудь будет настроен

## Коды возврата

| Код | Значение |
|---|---|
| 0 | успешно |
| 1 | ошибка (сеть, API, неверный ввод) |
| 130 | прервано пользователем |

## Лицензия

MIT. Основано на идее TG_Send, автор AdV1PeR.
