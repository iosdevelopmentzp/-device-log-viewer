#!/bin/zsh

LOGREADER_SUPPORT="${LOGREADER_SUPPORT_DIR:-$HOME/Library/Application Support/LogReader}"
UPDATE_SOURCE="$LOGREADER_SUPPORT/source"
UPDATE_DIR="$LOGREADER_SUPPORT/update"

iso_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

json_string() {
    if [[ -z "$1" ]]; then
        print -rn -- null
        return
    fi
    local value="${1//\\/\\\\}"
    value="${value//\"/\\\"}"
    print -rn -- "\"$value\""
}

write_json() {
    local file="$1" content="$2" temp
    mkdir -p "${file:h}"
    temp="$(mktemp "$file.XXXXXX")"
    print -r -- "$content" > "$temp"
    mv -f "$temp" "$file"
}

write_status() {
    [[ -n "${UPDATE_STATUS_FILE:-}" ]] || return 0
    local phase="$1" commit="${2:-}" message="${3:-}"
    write_json "$UPDATE_STATUS_FILE" \
        "{\"phase\": \"$phase\", \"startedAt\": \"${UPDATE_STARTED_AT:-$(iso_now)}\", \"commit\": $(json_string "$commit"), \"message\": $(json_string "$message")}"
}
