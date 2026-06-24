#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ReadyType"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
OUTPUT_PATH="${1:-$ROOT_DIR/dist/$APP_NAME.app.zip}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/readytype-package.XXXXXX")"
SANITIZED_APP_DIR="$TMP_DIR/$APP_NAME.app"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [[ ! -d "$APP_DIR" ]]; then
  echo "Missing app bundle: $APP_DIR" >&2
  echo "Run scripts/build-app.sh first." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"
rm -f "$OUTPUT_PATH"

ditto --norsrc "$APP_DIR" "$SANITIZED_APP_DIR"
xattr -cr "$SANITIZED_APP_DIR"
codesign --verify --deep --strict --verbose=2 "$SANITIZED_APP_DIR"
ditto -c -k --norsrc --keepParent "$SANITIZED_APP_DIR" "$OUTPUT_PATH"

echo "Packaged $OUTPUT_PATH"
