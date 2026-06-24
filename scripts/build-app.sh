#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
APP_NAME="ReadyType"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SWIFTPM_CACHE_DIR="$ROOT_DIR/.build/swiftpm-cache"
SWIFTPM_CONFIG_DIR="$ROOT_DIR/.build/swiftpm-config"
SWIFTPM_SECURITY_DIR="$ROOT_DIR/.build/swiftpm-security"
CLANG_MODULE_CACHE_DIR="$ROOT_DIR/.build/clang-module-cache"
VERIFY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/readytype-build-verify.XXXXXX")"
VERIFY_APP_DIR="$VERIFY_DIR/$APP_NAME.app"

cleanup() {
    rm -rf "$VERIFY_DIR"
}
trap cleanup EXIT

mkdir -p "$SWIFTPM_CACHE_DIR" "$SWIFTPM_CONFIG_DIR" "$SWIFTPM_SECURITY_DIR" "$CLANG_MODULE_CACHE_DIR"

export CLANG_MODULE_CACHE_PATH="$CLANG_MODULE_CACHE_DIR"

swift build \
    -c "$BUILD_CONFIG" \
    --product "$APP_NAME" \
    --disable-sandbox \
    --cache-path "$SWIFTPM_CACHE_DIR" \
    --config-path "$SWIFTPM_CONFIG_DIR" \
    --security-path "$SWIFTPM_SECURITY_DIR" \
    --manifest-cache local

mkdir -p "$DIST_DIR"
find "$DIST_DIR" -maxdepth 1 -type d -name "$APP_NAME*.app" -exec rm -rf {} +
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/$BUILD_CONFIG/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/ReadyType/ReadyType/Resources/ReadyTypeInfo.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/ReadyType/ReadyType/Resources/ReadyTypeAppIcon.icns" "$RESOURCES_DIR/ReadyTypeAppIcon.icns"
cp "$ROOT_DIR/ReadyType/ReadyType/Resources/ReadyTypeBrandLogo.svg" "$RESOURCES_DIR/ReadyTypeBrandLogo.svg"
cp "$ROOT_DIR/ReadyType/ReadyType/Resources/ReadyTypeMenuBarTemplate.png" "$RESOURCES_DIR/ReadyTypeMenuBarTemplate.png"
printf "APPL????" > "$CONTENTS_DIR/PkgInfo"
touch "$APP_DIR" "$CONTENTS_DIR" "$RESOURCES_DIR"
xattr -cr "$APP_DIR"
codesign --force --deep --sign - --no-strict "$APP_DIR"
xattr -cr "$APP_DIR"
ditto --norsrc "$APP_DIR" "$VERIFY_APP_DIR"
xattr -cr "$VERIFY_APP_DIR"
SetFile -a b "$VERIFY_APP_DIR" >/dev/null 2>&1 || true
codesign --verify --deep --strict --verbose=2 "$VERIFY_APP_DIR"

echo "Built $APP_DIR"
