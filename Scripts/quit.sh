#!/bin/zsh
set -euo pipefail

pgrep -x LogReader >/dev/null || exit 0
osascript -e 'tell application id "com.dev.com.LogReader" to quit' >/dev/null 2>&1 || true

for _ in {1..50}; do
    pgrep -x LogReader >/dev/null || exit 0
    sleep 0.2
done
pkill -x LogReader || true
