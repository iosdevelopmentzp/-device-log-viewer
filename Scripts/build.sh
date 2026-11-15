#!/bin/zsh
[ -n "${ZSH_VERSION:-}" ] || exec /bin/zsh "$0" "$@"
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-Debug}"
DERIVED="${LOGREADER_DERIVED_DATA:-$ROOT/DerivedData}"

"$ROOT/Scripts/check-anonymous.sh"

xcodebuild \
    -project "$ROOT/LogReader.xcodeproj" \
    -scheme LogReader \
    -configuration "$CONFIG" \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$DERIVED" \
    -quiet \
    build

echo "$DERIVED/Build/Products/$CONFIG/LogReader.app"
