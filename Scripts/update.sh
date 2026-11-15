#!/bin/zsh
set -uo pipefail

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/Scripts/update-files.sh"

LOCK="$UPDATE_DIR/update.lock"
export UPDATE_STATUS_FILE="$UPDATE_DIR/status.json"
export UPDATE_STARTED_AT="$(iso_now)"

fail() {
    write_status failed "" "$1"
    echo "$1"
    exit 1
}

main() {
    mkdir -p "$UPDATE_DIR"
    if [[ -f "$LOCK" ]] && kill -0 "$(< "$LOCK")" 2>/dev/null; then
        echo "Another update is running (pid $(< "$LOCK"))"
        exit 0
    fi
    echo $$ > "$LOCK"
    trap '[[ "$(< "$LOCK")" == "$$" ]] && rm -f "$LOCK"' EXIT

    echo "Update started at $UPDATE_STARTED_AT in $UPDATE_SOURCE"
    write_status fetching
    [[ -d "$UPDATE_SOURCE/.git" ]] || fail "The build folder is missing. Run Scripts/install.sh again"
    git -C "$UPDATE_SOURCE" fetch --quiet origin main \
        && git -C "$UPDATE_SOURCE" reset --quiet --hard origin/main \
        || fail "Could not get the changes"
    echo "Building $(git -C "$UPDATE_SOURCE" log -1 --format='%h %s')"

    "$UPDATE_SOURCE/Scripts/install.sh" || fail "The build failed. See the log"
}

main "$@"
