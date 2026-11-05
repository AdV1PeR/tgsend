#!/usr/bin/env bash
#
# tgsend — отправка сообщений и файлов через Telegram Bot API.
#
#   tgsend -m "текст"           отправить сообщение (длинный текст режется на части)
#   tgsend -f file [-c "подпись"]   отправить файл
#   tgsend -n ...               dry-run: проверить, ничего не отправляя
#   tgsend -v | -h              версия / справка
#
# Конфиг: ~/.config/tgsend/config (или $TG_CONF)
#   TG_BOT_TOKEN="123456:ABC..."
#   TG_CHAT_ID="123456789"
#
# Лог: ~/.local/log/tgsend/tgsend.log (ротация 1 МБ)
# Лицензия: MIT
#
set -euo pipefail

readonly VERSION="1.3"
readonly TG_CONF="${TG_CONF:-${HOME}/.config/tgsend/config}"

if [ -f "${TG_CONF}" ]; then
    set -a
    # shellcheck disable=SC1090
    . "${TG_CONF}"
    set +a
fi

readonly BOT_TOKEN="${TG_BOT_TOKEN:-}"
CHAT_ID="${TG_CHAT_ID:-}"
readonly MAX_FILE_SIZE="${TG_MAX_FILE_SIZE:-50000000}"   # 50 МБ — лимит Bot API
readonly MAX_TEXT=4096
readonly CHUNK=4000
readonly CAPTION_MAX=1024
readonly LOG_DIR="${HOME}/.local/log/tgsend"
readonly LOG_FILE="${LOG_DIR}/tgsend.log"
readonly API="https://api.telegram.org/bot${BOT_TOKEN}"
readonly LOG_MAX=1048576

readonly CURL=(curl -sS --connect-timeout 15 --max-time 180 \
    --retry 2 --retry-delay 5 --retry-connrefused)

QUIET=0
MARKDOWN=0
HTML=0
SILENT=0
DRY_RUN=0
TOPIC=""

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'

# ---------- логирование ----------
init_logging() {
    mkdir -p "${LOG_DIR}"
    if [ -f "${LOG_FILE}" ] && [ "$(stat -c%s "${LOG_FILE}" 2>/dev/null || echo 0)" -ge "${LOG_MAX}" ]; then
        mv -f "${LOG_FILE}" "${LOG_FILE}.1"
    fi
    touch "${LOG_FILE}"
    chmod 600 "${LOG_FILE}"
    exec 3>>"${LOG_FILE}"
}

log() { printf '%s [%-7s] %s\n' "$(date '+%Y-%m-%d %T')" "$1" "$2" >&3; }
say()    { [ "${QUIET}" -eq 1 ] || echo -e "$*"; }
say_ok() { say "${GREEN}✓${NC} $*"; }

die() {
    local msg="$1" code="${2:-1}"
    echo -e "${RED}ERROR:${NC} ${msg}" >&2
    log "ERROR" "${msg}"
    exit "${code}"
}

# ---------- проверки ----------
validate_deps() {
    local dep missing=()
    for dep in curl jq; do
        command -v "${dep}" >/dev/null 2>&1 || missing+=("${dep}")
    done
    [ ${#missing[@]} -eq 0 ] || die "Не найдены зависимости: ${missing[*]}"
}

validate_credentials() {
    [ -n "${BOT_TOKEN}" ] || die "Не задан TG_BOT_TOKEN (${TG_CONF})"
    [ -n "${CHAT_ID}" ]   || die "Не задан TG_CHAT_ID (${TG_CONF})"
    [[ "${BOT_TOKEN}" =~ ^[0-9]{8,12}:[A-Za-z0-9_-]{30,}$ ]] || die "Неверный формат токена"

    if [ "${DRY_RUN}" -eq 1 ]; then return 0; fi

    local response
    response="$("${CURL[@]}" --max-time 20 "${API}/getMe" || true)"
    if ! jq -e '.ok == true' <<<"${response}" >/dev/null 2>&1; then
        local err
        err="$(jq -r '.description // "нет ответа"' <<<"${response}" 2>/dev/null)"
        case "${err}" in
            Unauthorized) die "Токен отклонён (401). Проверь TG_BOT_TOKEN" ;;
            *)            die "Проверка токена не прошла: ${err}" ;;
        esac
    fi
}

# ---------- Telegram API ----------
# request <url> [curl-args...] — POST, один повтор при 429
request() {
    local url="$1"; shift
    local response attempt=1 retry_after
    while :; do
        response="$("${CURL[@]}" -X POST "${url}" "$@" || true)"
        if [ -z "${response}" ]; then
            log "ERROR" "пустой ответ API"
            return 1
        fi
        if jq -e '.ok == true' <<<"${response}" >/dev/null 2>&1; then
            printf '%s' "${response}"
            return 0
        fi
        retry_after="$(jq -r '.parameters.retry_after // empty' <<<"${response}" 2>/dev/null || true)"
        if [ "${attempt}" -eq 1 ] && [ -n "${retry_after}" ]; then
            log "WARN" "429, пауза ${retry_after}s"
            say "${YELLOW}…${NC} rate limit, ждём ${retry_after}s"
            sleep "${retry_after}"
            attempt=2
            continue
        fi
        printf '%s' "${response}"
        return 1
    done
}

api_error() {
    local response="$1"
    if [ -z "${response}" ]; then
        echo "нет ответа от API (проверь сеть)"
        return
    fi
    jq -r '.description // "Неизвестная ошибка"' <<<"${response}" 2>/dev/null \
        || echo "не удалось разобрать ответ API"
}

handle_result() {
    local response="$1" kind="$2"
    if jq -e '.ok == true' <<<"${response}" >/dev/null 2>&1; then
        log "SUCCESS" "${kind} delivered"
        say_ok "Отправлено"
        return 0
    fi
    local err; err="$(api_error "${response}")"
    log "ERROR" "${kind}: ${err}"
    say "${RED}✗${NC} ${err}"
    return 1
}

build_common_args() {
    COMMON_ARGS=(-d "chat_id=${CHAT_ID}")
    if [ "${SILENT}" -eq 1 ]; then COMMON_ARGS+=(-d "disable_notification=true"); fi
    if [ -n "${TOPIC}" ]; then COMMON_ARGS+=(-d "message_thread_id=${TOPIC}"); fi
}

send_one() {
    local text="$1"
    local args=("${COMMON_ARGS[@]}")
    args+=(--data-urlencode "text=${text}")
    if [ "${MARKDOWN}" -eq 1 ]; then args+=(-d "parse_mode=MarkdownV2"); fi
    if [ "${HTML}" -eq 1 ]; then args+=(-d "parse_mode=HTML"); fi

    if [ "${DRY_RUN}" -eq 1 ]; then
        say "[dry-run] сообщение ${#text} симв."
        log "INFO" "dry-run message (${#text} chars)"
        return 0
    fi

    local response
    if ! response="$(request "${API}/sendMessage" "${args[@]}")"; then
        handle_result "${response}" message || return 1
        return 1
    fi
    handle_result "${response}" message
}

send_message() {
    local text="$1"
    build_common_args

    if [ "${#text}" -le "${MAX_TEXT}" ]; then
        send_one "${text}"
        return
    fi

    log "INFO" "длинное сообщение: ${#text} символов, режем"
    local chunk="" line
    while IFS= read -r line || [ -n "${line}" ]; do
        # не разрываем строки без нужды
        if [ -n "${chunk}" ] && [ $(( ${#chunk} + ${#line} + 1 )) -gt "${CHUNK}" ]; then
            send_one "${chunk}" || return 1
            chunk=""
        fi
        # аномально длинную строку режем принудительно
        while [ "${#line}" -gt "${CHUNK}" ]; do
            send_one "${line:0:${CHUNK}}" || return 1
            line="${line:${CHUNK}}"
        done
        if [ -z "${chunk}" ]; then
            chunk="${line}"
        else
            chunk="${chunk}"$'\n'"${line}"
        fi
    done <<< "${text}"
    if [ -n "${chunk}" ]; then send_one "${chunk}"; fi
}

send_file() {
    local file="$1" caption="${2:-${TG_CAPTION:-}}"

    [ -e "${file}" ] || die "Файл не найден: ${file}"
    [ -f "${file}" ] || die "Это не обычный файл: ${file}"
    [ -r "${file}" ] || die "Нет доступа на чтение: ${file}"

    local size
    size="$(stat -c%s "${file}")"
    [ "${size}" -gt 0 ] || die "Файл пустой: ${file}"
    [ "${size}" -le "${MAX_FILE_SIZE}" ] || die "Файл больше лимита (${size} > ${MAX_FILE_SIZE} Б)"
    [ "${#caption}" -le "${CAPTION_MAX}" ] || die "Подпись длиннее ${CAPTION_MAX} символов"

    # Файл шлём только multipart: смешивать -d и -F нельзя, curl теряет тело.
    local args=(-F "chat_id=${CHAT_ID}")
    if [ "${SILENT}" -eq 1 ]; then args+=(-F "disable_notification=true"); fi
    if [ -n "${TOPIC}" ]; then args+=(-F "message_thread_id=${TOPIC}"); fi
    if [ -n "${caption}" ]; then args+=(-F "caption=${caption}"); fi
    args+=(-F "document=@${file}")

    if [ "${DRY_RUN}" -eq 1 ]; then
        say "[dry-run] файл $(basename "${file}"), ${size} Б"
        log "INFO" "dry-run file (${size} B)"
        return 0
    fi

    log "INFO" "file $(basename "${file}") (${size} B)"
    local response
    if ! response="$(request "${API}/sendDocument" "${args[@]}")"; then
        handle_result "${response}" file || return 1
        return 1
    fi
    handle_result "${response}" file
}

# ---------- CLI ----------
usage() {
    cat <<EOF
tgsend ${VERSION} — отправка через Telegram Bot API

Использование: ${0##*/} [ОПЦИИ] [КОНТЕНТ]

  -m, --message TEXT    сообщение (длинное режется на части)
  -f, --file FILE       файл
  -c, --caption TEXT    подпись к файлу (или TG_CAPTION)
  -C, --chat ID         получатель вместо TG_CHAT_ID
  -M, --markdown        parse_mode=MarkdownV2
  -H, --html            parse_mode=HTML
  -s, --silent          без звука (disable_notification)
  -t, --topic ID        message_thread_id (форумы)
  -n, --dry-run         проверить, ничего не отправлять
  -q, --quiet           без вывода в консоль
  -v, --version         версия
  -h, --help            справка
  --                    конец опций

Конфиг: ${TG_CONF}
  TG_BOT_TOKEN="..."
  TG_CHAT_ID="..."

Примеры:
  ${0##*/} -m "Привет"
  ${0##*/} -f backup.tar.gz -c "еженедельный бэкап"
  ${0##*/} -n -f big.zip -c "проверка"
EOF
}

parse_args() {
    local kind="" content="" caption="${TG_CAPTION:-}"

    while [ $# -gt 0 ]; do
        case "$1" in
            -m|--message) [ $# -ge 2 ] || die "После $1 нужен текст"; kind="text"; content="$2"; shift 2 ;;
            -f|--file)    [ $# -ge 2 ] || die "После $1 нужен путь"; kind="file"; content="$2"; shift 2 ;;
            -c|--caption) [ $# -ge 2 ] || die "После $1 нужна подпись"; caption="$2"; shift 2 ;;
            -C|--chat)    [ $# -ge 2 ] || die "После $1 нужен chat_id"; CHAT_ID="$2"; shift 2 ;;
            -t|--topic)   [ $# -ge 2 ] || die "После $1 нужен thread_id"; TOPIC="$2"; shift 2 ;;
            -M|--markdown) MARKDOWN=1; shift ;;
            -H|--html)     HTML=1; shift ;;
            -s|--silent)   SILENT=1; shift ;;
            -n|--dry-run)  DRY_RUN=1; shift ;;
            -q|--quiet)    QUIET=1; shift ;;
            -v|--version)  echo "tgsend ${VERSION}"; exit 0 ;;
            -h|--help)     usage; exit 0 ;;
            --)
                shift
                if [ $# -gt 0 ]; then
                    content="$1"
                    kind=$([ -f "$1" ] && echo file || echo text)
                    shift
                fi
                ;;
            -*) die "Неизвестная опция: $1" ;;
            *)  content="$1"; kind=$([ -f "$1" ] && echo file || echo text); shift ;;
        esac
    done

    [ -n "${content}" ] || die "Не задан контент (см. -h)"
    if [ "${MARKDOWN}" -eq 1 ] && [ "${HTML}" -eq 1 ]; then die "-M и -H взаимоисключающие"; fi

    case "${kind}" in
        text) send_message "${content}" ;;
        file) send_file "${content}" "${caption}" ;;
        *)    die "Не удалось определить тип контента" ;;
    esac
}

main() {
    init_logging
    log "INFO" "start (v${VERSION})"
    trap 'log "WARN" "interrupted"; exit 130' INT TERM
    parse_args "$@"
    validate_deps
    validate_credentials
    log "INFO" "done"
}

main "$@"
