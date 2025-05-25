#!/usr/bin/env bash
set -euo pipefail

# Telegram Bot API Interface
# Version: 1.1
# Author: AdV1PeR
# License: MIT

# Configuration (edit these values)
declare -r BOT_TOKEN=""   # <--- YOUR BOT TOKEN
declare -r CHAT_ID=""     # <--- YOUR TELEGRAM ID
declare -r MAX_FILE_SIZE=50000000  # 50MB (Telegram limit)

# Logging settings
declare -r LOG_DIR="${HOME}/.local/log/tgsend"
declare -r LOG_FILE="${LOG_DIR}/tgsend.log"

# API endpoints
declare -r API_URL="https://api.telegram.org/bot${BOT_TOKEN}"
declare -r SEND_MSG_URL="${API_URL}/sendMessage"
declare -r SEND_FILE_URL="${API_URL}/sendDocument"
declare -r GET_UPDATES_URL="${API_URL}/getUpdates"

# Text formatting
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[0;33m'
declare -r BLUE='\033[0;34m'
declare -r NC='\033[0m'

init_logging() {
    mkdir -p "${LOG_DIR}"
    touch "${LOG_FILE}" 2>/dev/null || {
        echo -e "${RED}Failed to create log file${NC}" >&2
        exit 1
    }
    chmod 600 "${LOG_FILE}"
    exec 3>>"${LOG_FILE}"
    log "INFO" "Session started: $(date)"
}

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %T")
    printf "%s [%-5s] %s\n" "${timestamp}" "${level}" "${message}" >&3
}

validate_dependencies() {
    local dependencies=("curl" "jq" "file")
    local missing=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "${dep}" &> /dev/null; then
            missing+=("${dep}")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        error_exit "Missing dependencies: ${missing[*]}"
    fi
}

validate_credentials() {
    if [[ ! "${BOT_TOKEN}" =~ ^[0-9]{8,10}:[a-zA-Z0-9_-]{35}$ ]]; then
        error_exit "Invalid bot token format"
    fi

    local response=$(curl -s "${GET_UPDATES_URL}")
    if ! echo "${response}" | jq -e '.ok' | grep -q true; then
        error_exit "Token validation failed: $(echo "${response}" | jq -r '.description')"
    fi
}

error_exit() {
    local msg="$1"
    local code="${2:-1}"
    echo -e "${RED}ERROR:${NC} ${msg}" >&2
    log "ERROR" "${msg}"
    exit "${code}"
}

send_message() {
    local text="$1"
    local encoded_text=$(jq -rn --arg t "${text}" '$t | @uri')
    
    log "INFO" "Sending message: ${text:0:50}..."
    
    local response=$(curl -s -X POST "${SEND_MSG_URL}" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${encoded_text}" \
        -d "parse_mode=markdown" \
        -H "Content-Type: application/x-www-form-urlencoded")

    process_response "${response}"
}

send_file() {
    local file_path="$1"
    
    if [ ! -f "${file_path}" ]; then
        error_exit "File not found: ${file_path}"
    fi

    local mime_type=$(file --mime-type -b "${file_path}")
    local file_size=$(stat -c%s "${file_path}")

    log "INFO" "Preparing to send file: ${file_path} (Type: ${mime_type}, Size: ${file_size})"

    if [ "${file_size}" -gt "${MAX_FILE_SIZE}" ]; then
        error_exit "File size exceeds Telegram limit (50MB)"
    fi

    local response=$(curl -s -X POST "${SEND_FILE_URL}" \
        -F "chat_id=${CHAT_ID}" \
        -F "document=@\"${file_path}\"" \
        -H "Content-Type: multipart/form-data")

    process_response "${response}"
}

process_response() {
    local response="$1"
    local status=$(echo "${response}" | jq -r '.ok')

    if [ "${status}" == "true" ]; then
        log "SUCCESS" "Content delivered successfully"
        echo -e "${GREEN}✓ Successfully sent!${NC}"
    else
        local error_msg=$(echo "${response}" | jq -r '.description // "Unknown error"')
        log "ERROR" "API Error: ${error_msg}"
        error_exit "API Error: ${error_msg}"
    fi
}

show_usage() {
    cat <<EOF
Telegram Content Sender (v3.1)

Usage: ${0##*/} [OPTIONS] [CONTENT]

Options:
  -m, --message TEXT   Send text message
  -f, --file FILE      Send file
  -v, --version        Show version
  -h, --help           Show this help

Examples:
  ${BLUE}Send message:${NC}   ${0##*/} -m "Hello World!"
  ${BLUE}Send file:${NC}      ${0##*/} -f document.pdf
EOF
}

parse_arguments() {
    local content=""
    local content_type=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--message)
                content_type="text"
                content="$2"
                shift 2
                ;;
            -f|--file)
                content_type="file"
                content="$2"
                shift 2
                ;;
            -v|--version)
                echo "Telegram Sender v1.1"
                exit 0
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                error_exit "Unknown option: $1"
                ;;
            *)
                content="$1"
                [ -f "${content}" ] && content_type="file" || content_type="text"
                shift
                ;;
        esac
    done

    if [ -z "${content}" ]; then
        error_exit "No content specified"
    fi

    case "${content_type}" in
        "text") send_message "${content}" ;;
        "file") send_file "${content}" ;;
        *) error_exit "Invalid content type" ;;
    esac
}

main() {
    init_logging
    validate_dependencies
    validate_credentials
    parse_arguments "$@"
}

trap 'log "WARNING" "Script interrupted by user"; exit 130' INT TERM
main "$@"
