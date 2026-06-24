#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/ReadyType.app"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/ReadyType"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing $APP_PATH. Run ./scripts/build-app.sh first."
  exit 1
fi

TMP_DIR="$(mktemp -d)"
TMP_DIR="$(cd "$TMP_DIR" && pwd -P)"
TARGET_FILE="$TMP_DIR/readytype-textedit-paste.txt"
POSTER_FILE="$TMP_DIR/post-readytype-debug-insert.swift"
MARKER="ReadyType paste acceptance $(date +%s)"
TEXTEDIT_WAS_RUNNING=0
ORIGINAL_CLIPBOARD=""
READYTYPE_PID=""

quit_readytype_instances() {
  osascript -e 'tell application "ReadyType" to quit' >/dev/null 2>&1 || true

  for _ in {1..15}; do
    if ! pgrep -x ReadyType >/dev/null 2>&1; then
      return
    fi
    sleep 0.2
  done

  pkill -x ReadyType >/dev/null 2>&1 || true

  for _ in {1..15}; do
    if ! pgrep -x ReadyType >/dev/null 2>&1; then
      return
    fi
    sleep 0.2
  done
}

cleanup() {
  osascript - "$TARGET_FILE" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  set targetPath to item 1 of argv
  tell application "TextEdit"
    repeat with doc in documents
      try
        if path of doc is targetPath then close doc saving no
      end try
    end repeat
  end tell
end run
APPLESCRIPT

  if [[ "$TEXTEDIT_WAS_RUNNING" == "0" ]]; then
    osascript -e 'tell application "TextEdit" to quit' >/dev/null 2>&1 || true
  fi

  if [[ -n "$READYTYPE_PID" ]]; then
    kill "$READYTYPE_PID" >/dev/null 2>&1 || true
  fi
  quit_readytype_instances

  if [[ -n "$ORIGINAL_CLIPBOARD" ]]; then
    printf "%s" "$ORIGINAL_CLIPBOARD" | pbcopy || true
  fi

  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if pgrep -x TextEdit >/dev/null 2>&1; then
  TEXTEDIT_WAS_RUNNING=1
  OPEN_TEXTEDIT_DOCUMENTS="$(osascript -e 'tell application "TextEdit" to count documents' 2>/dev/null || echo 0)"
  if [[ "$OPEN_TEXTEDIT_DOCUMENTS" =~ ^[0-9]+$ ]] && [[ "$OPEN_TEXTEDIT_DOCUMENTS" -gt 0 ]]; then
    echo "TextEdit is already running with open documents. Close or save those documents before running this paste acceptance script." >&2
    echo "This guard prevents diagnostic text from being inserted into a user document instead of the temporary acceptance document." >&2
    exit 1
  fi
fi

ORIGINAL_CLIPBOARD="$(pbpaste 2>/dev/null || true)"
printf "" > "$TARGET_FILE"

quit_readytype_instances

open -a TextEdit "$TARGET_FILE"
sleep 1.0

osascript - "$TARGET_FILE" <<'APPLESCRIPT'
on run argv
  set targetPath to item 1 of argv
  tell application "TextEdit"
    activate
    repeat with doc in documents
      try
        if path of doc is targetPath then
          set frontmost of doc to true
          return
        end if
      end try
    end repeat
  end tell
end run
APPLESCRIPT

# Launch ReadyType only after TextEdit is frontmost. The app captures the last
# non-ReadyType target during startup, matching the real recording flow where
# the target is captured before ReadyType brings its own UI forward.
READYTYPE_ENABLE_DEBUG_INSERT=1 READYTYPE_SUPPRESS_LAUNCH_WINDOW=1 "$APP_EXECUTABLE" >/tmp/readytype-textedit-paste-app.log 2>&1 &
READYTYPE_PID=$!
sleep 1.5

cat > "$POSTER_FILE" <<'SWIFT'
import Foundation

guard CommandLine.arguments.count == 2 else {
    fatalError("Expected one text argument.")
}

Thread.sleep(forTimeInterval: 3.0)

DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("readyTypeDebugInsertRequested"),
    object: nil,
    userInfo: ["text": CommandLine.arguments[1]],
    deliverImmediately: true
)
SWIFT

swift "$POSTER_FILE" "$MARKER" &
POSTER_PID=$!

for _ in {1..20}; do
  osascript - "$TARGET_FILE" <<'APPLESCRIPT'
on run argv
  set targetPath to item 1 of argv
  tell application "TextEdit"
    activate
    repeat with doc in documents
      try
        if path of doc is targetPath then
          set frontmost of doc to true
          return
        end if
      end try
    end repeat
  end tell
end run
APPLESCRIPT
  sleep 0.2
done

wait "$POSTER_PID"
sleep 1.5

TEXTEDIT_TEXT="$(osascript - "$TARGET_FILE" <<'APPLESCRIPT'
on run argv
  set targetPath to item 1 of argv
  tell application "TextEdit"
    repeat with doc in documents
      try
        if path of doc is targetPath then return text of doc
      end try
    end repeat
  end tell
  return ""
end run
APPLESCRIPT
)"

if [[ "$TEXTEDIT_TEXT" == *"$MARKER"* ]]; then
  echo "ReadyType 1.2 TextEdit paste check passed."
  exit 0
fi

CLIPBOARD_TEXT="$(pbpaste 2>/dev/null || true)"
if [[ "$CLIPBOARD_TEXT" == *"$MARKER"* ]]; then
  echo "ReadyType copied the diagnostic text to the clipboard instead of pasting into TextEdit."
  exit 2
fi

echo "ReadyType TextEdit paste check failed: diagnostic text was not found in TextEdit or clipboard."
exit 1
