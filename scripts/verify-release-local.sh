#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="$(plutil -extract CFBundleShortVersionString raw ReadyType/ReadyType/Resources/ReadyTypeInfo.plist)"
BUILD="$(plutil -extract CFBundleVersion raw ReadyType/ReadyType/Resources/ReadyTypeInfo.plist)"
APP_ID="${READYTYPE_TELEMETRYDECK_APP_ID:-}"
RUN_REAL_AI="${RUN_REAL_AI:-0}"
RUN_API_FAILURES="${RUN_API_FAILURES:-0}"
RUN_TEXTEDIT_PASTE="${RUN_TEXTEDIT_PASTE:-0}"

log_step() {
    printf "\n==> %s\n" "$1"
}

if [[ ! "$APP_ID" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then
    echo "Set READYTYPE_TELEMETRYDECK_APP_ID to the official app UUID before release verification." >&2
    exit 1
fi

log_step "swift test"
swift test

log_step "official app build"
scripts/build-app.sh

BUILT_APP_ID="$(plutil -extract ReadyTypeTelemetryDeckAppID raw dist/ReadyType.app/Contents/Info.plist)"
[[ "$BUILT_APP_ID" == "$APP_ID" ]] || { echo "Built app has the wrong analytics App ID." >&2; exit 1; }
if plutil -extract ReadyTypeTelemetryDeckTestMode raw dist/ReadyType.app/Contents/Info.plist >/dev/null 2>&1; then
    echo "Release build must not enable TelemetryDeck Test Mode." >&2
    exit 1
fi

log_step "strict app-bundle signature check"
TMP_APP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/readytype-codesign.XXXXXX")"
trap 'rm -rf "$TMP_APP_DIR"' EXIT
ditto --norsrc dist/ReadyType.app "$TMP_APP_DIR/ReadyType.app"
xattr -cr "$TMP_APP_DIR/ReadyType.app"
codesign --verify --deep --strict --verbose=2 "$TMP_APP_DIR/ReadyType.app"

log_step "release packages"
scripts/package-app.sh
scripts/package-dmg.sh
hdiutil verify dist/ReadyType.dmg

log_step "current UI"
scripts/verify-ui.sh

log_step "metadata and repository checks"
plutil -lint ReadyType/ReadyType/Resources/ReadyTypeInfo.plist
git diff --check
python3 scripts/check-sensitive-info.py

if [[ "$RUN_REAL_AI" == "1" ]]; then
    log_step "real DeepSeek acceptance"
    scripts/verify-1.2-real-ai-output.sh
fi

if [[ "$RUN_API_FAILURES" == "1" ]]; then
    log_step "real API failure acceptance"
    scripts/verify-1.2-api-error-paths.sh
fi

if [[ "$RUN_TEXTEDIT_PASTE" == "1" ]]; then
    log_step "TextEdit paste acceptance"
    scripts/verify-1.2-textedit-paste.sh
fi

printf "\nReadyType %s (%s) local release gate passed.\n" "$VERSION" "$BUILD"
