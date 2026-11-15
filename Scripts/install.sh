#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/Scripts/update-files.sh"

LIVE_TARGET="/Applications/LogReader.app"
TARGET="${LOGREADER_INSTALL_TARGET:-$LIVE_TARGET}"
DERIVED="$ROOT/DerivedData/Install"
IDENTITY="${LOGREADER_SIGN_IDENTITY:-}"
for IDENTITY_FILE in "$HOME/.config/logreader/sign-identity"; do
    if [[ -z "$IDENTITY" && -f "$IDENTITY_FILE" ]]; then
        IDENTITY="$(tr -d '[:space:]' < "$IDENTITY_FILE")"
    fi
done

if [[ ! -d "$UPDATE_SOURCE/.git" && "${ROOT:A}" != "${UPDATE_SOURCE:A}" ]]; then
    mkdir -p "$LOGREADER_SUPPORT"
    git clone --quiet --config core.hooksPath=/dev/null --branch main "$ROOT" "$UPDATE_SOURCE"
fi

write_status building
LOGREADER_DERIVED_DATA="$DERIVED" "$ROOT/Scripts/build.sh" Release
APP="$DERIVED/Build/Products/Release/LogReader.app"

write_status installing
STAGED="$TARGET.new"
rm -rf "$STAGED"
cp -R "$APP" "$STAGED"
if [[ -n "$IDENTITY" ]]; then
    codesign --force --sign "$IDENTITY" --preserve-metadata=identifier,entitlements "$STAGED"
fi

if [[ "$TARGET" == "$LIVE_TARGET" ]]; then
    "$ROOT/Scripts/quit.sh"
fi
rm -rf "$TARGET"
mv "$STAGED" "$TARGET"
touch "$TARGET"

COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
write_json "$UPDATE_DIR/installed.json" \
    "{\"commit\": \"$COMMIT\", \"branch\": \"main\", \"source\": $(json_string "$UPDATE_SOURCE"), \"installedAt\": \"$(iso_now)\"}"
if [[ -n "${UPDATE_STATUS_FILE:-}" ]]; then
    write_status done "$COMMIT"
else
    rm -f "$UPDATE_DIR/status.json"
fi

if [[ "$TARGET" == "$LIVE_TARGET" ]]; then
    open "$TARGET"
fi
echo "Installed $TARGET at ${COMMIT[1,7]} (signed: ${IDENTITY:-ad-hoc})"
