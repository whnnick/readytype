#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 || ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || ! "$2" =~ ^[1-9][0-9]*$ ]]; then
  echo "Usage: scripts/set-version.sh <version> <build-number>" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST="$ROOT_DIR/ReadyType/ReadyType/Resources/ReadyTypeInfo.plist"

/usr/bin/sed -E -i '' "/<key>CFBundleShortVersionString<\\/key>/{n;s#<string>[^<]+</string>#<string>$1</string>#;}" "$PLIST"
/usr/bin/sed -E -i '' "/<key>CFBundleVersion<\\/key>/{n;s#<string>[^<]+</string>#<string>$2</string>#;}" "$PLIST"
/usr/bin/plutil -lint "$PLIST" >/dev/null

echo "ReadyType version set to $1 ($2)"
