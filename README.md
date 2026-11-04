# tgsend

Отправка сообщений и файлов через Telegram Bot API из bash.
Без зависимостей кроме `curl` и `jq`. Подходит для cron, CI и всяких
автоматизаций: бэкапы, алерты, отчёты.

## Возможности

- текст и файлы до 50 МБ (лимит Bot API)
- длинные сообщения автоматически режутся на части по 4000 символов
  с переносом по строкам
- `MarkdownV2` и `HTML` — по флагу, по умолчанию текст отправляется как есть
- таймауты, ретраи и корректная обработка `429 Too Many Requests`
  (`retry_after` соблюдается)
- `--dry-run` — проверить, ничего не отправляя
- `--silent`, `--topic` (форумы), `--chat` (получатель на один вызов)
- креды в отдельном файле, а не в скрипте
- лог с ротацией на 1 МБ
- внятные ошибки и коды возврата

## Требования

- `bash` 4.4+
- `curl`
- `jq`

## Установка

```bash
git clone https://github.com/AdV1PeR/tgsend.git
cd tgsend
chmod +x tgsend.sh
install -m 755 tgsend.sh ~/.local/bin/tgsend
```

Или просто запускать `./tgsend.sh`.

## Настройка

Создайте `~/.config/tgsend/config`:

```bash
TG_BOT_TOKEN="123456789:AA..."
TG_CHAT_ID="123456789"
```

Файл должен быть закрыт: `chmod 600 ~/.config/tgsend/config`.
Другой путь можно задать через `TG_CONF=/path/to/config`.

Как получить:

- токен — у [@BotFather](https://t.me/BotFather) (`/newbot`)
- `chat_id` — написать боту `/start`, затем
  `curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | jq '.result[0].message.chat.id'`

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

Переменные окружения:

| Переменная | Значение |
|---|---|
| `TG_BOT_TOKEN` | токен бота |
| `TG_CHAT_ID` | получатель по умолчанию |
| `TG_CAPTION` | подпись к файлу |
| `TG_CONF` | путь к конфигу |
| `TG_MAX_FILE_SIZE` | свой лимит размера файла |

## Логи

`~/.local/log/tgsend/tgsend.log` (права 600). Ротация: при 1 МБ файл
становится `tgsend.log.1`. Токен и chat_id в лог не пишутся.

## Termux

Termux не имеет `/usr/bin/env`, поэтому если при запуске
`bad interpreter`, используйте обёртку:

```bash
pkg install bash curl jq
bash tgsend.sh -m "test"
```

или замените shebang на
`#!/data/data/com.termux/files/usr/bin/bash`.

## Безопасность

- токен хранится только в конфиге с правами 600
- токен не попадает в аргументы командной строки, логи и ошибки
- `--dry-run` не делает сетевых запросов
- скрипт не скачивает и не исполняет ничего извне

## Коды возврата

| Код | Значение |
|---|---|
| 0 | успешно |
| 1 | ошибка (сеть, API, неверный ввод) |
| 130 | прервано пользователем |

## Лицензия

MIT. Основано на идее TG_Send, автор AdV1PeR.
