#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/ReadyType.app"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/ReadyType"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/ReadyType/ReadyType/Resources/ReadyTypeInfo.plist")"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/readytype-common-words-ui.XXXXXX")"
VOCABULARY_FILE="$TMP_DIR/UserVocabulary.json"
READYTYPE_PID=""
OSASCRIPT_TIMEOUT_SECONDS="${OSASCRIPT_TIMEOUT_SECONDS:-8}"
MARKER="ReadyTypeAcceptanceTerm$(date +%s)"

quit_readytype_instances() {
    /usr/bin/osascript -e 'tell application "ReadyType" to quit' >/dev/null 2>&1 || true

    for _ in {1..15}; do
        if ! pgrep -x ReadyType >/dev/null 2>&1; then
            return
        fi
        sleep 0.2
    done

    pkill -x ReadyType >/dev/null 2>&1 || true
}

cleanup() {
    if [[ -n "$READYTYPE_PID" ]]; then
        kill "$READYTYPE_PID" >/dev/null 2>&1 || true
        wait "$READYTYPE_PID" >/dev/null 2>&1 || true
    fi
    quit_readytype_instances
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

run_osascript() {
    local description="$1"
    local output_file="$2"
    shift 2

    local error_file="$TMP_DIR/osascript-error.txt"
    : > "$error_file"

    local status=0
    /usr/bin/perl -e '
        $timeout = shift;
        $pid = fork();
        die "fork failed\n" unless defined $pid;
        if ($pid == 0) {
            exec @ARGV;
            exit 127;
        }
        $SIG{ALRM} = sub {
            kill "TERM", $pid;
            sleep 1;
            kill "KILL", $pid;
            exit 124;
        };
        alarm $timeout;
        waitpid $pid, 0;
        $status = $?;
        exit(128 + ($status & 127)) if ($status & 127);
        exit($status >> 8);
    ' \
        "$OSASCRIPT_TIMEOUT_SECONDS" \
        /usr/bin/osascript "$@" > "$output_file" 2> "$error_file" || status=$?

    if [[ "$status" -eq 0 ]]; then
        return
    fi

    if [[ "$status" -eq 124 ]]; then
        echo "AppleScript timed out while checking: $description" >&2
        echo "This usually means macOS System Events or Accessibility automation is unavailable in the current GUI session." >&2
        exit 1
    fi

    echo "AppleScript failed while checking: $description" >&2
    cat "$error_file" >&2
    exit "$status"
}

wait_for_readytype_window() {
    local output_file="$TMP_DIR/window-count.txt"

    for _ in {1..50}; do
        run_osascript "ReadyType window count" "$output_file" \
            -e 'tell application "System Events"
                    if exists process "ReadyType" then
                        tell process "ReadyType" to count windows
                    else
                        return 0
                    end if
                end tell'

        if grep -Eq '^[1-9][0-9]*$' "$output_file"; then
            return 0
        fi
        sleep 0.2
    done

    return 1
}

click_sidebar_button() {
    local button_index="$1"
    local output_file="$TMP_DIR/click-$button_index.txt"
    run_osascript "ReadyType sidebar button $button_index" "$output_file" \
        -e "tell application \"System Events\" to tell process \"ReadyType\" to click button $button_index of group 1 of window 1"
}

dump_scroll_area() {
    local output_file="$1"
    run_osascript "ReadyType visible scroll area" "$output_file" \
        -e 'tell application "System Events" to tell process "ReadyType" to get properties of UI elements of scroll area 1 of group 1 of window 1'
}

if [[ ! -x "$APP_EXECUTABLE" ]]; then
    echo "Missing app executable: $APP_EXECUTABLE" >&2
    echo "Run scripts/build-app.sh first." >&2
    exit 1
fi

quit_readytype_instances

READYTYPE_ENABLE_DEBUG_VOCABULARY=1 \
READYTYPE_DEBUG_VOCABULARY_FILE="$VOCABULARY_FILE" \
READYTYPE_DEBUG_VOCABULARY_VALUE="$MARKER" \
"$APP_EXECUTABLE" \
    -voiceShortcutTrigger doubleOption \
    -voiceShortcutDoublePressInterval 0.45 \
    > "$TMP_DIR/readytype.log" 2>&1 &
READYTYPE_PID=$!

if ! wait_for_readytype_window; then
    echo "ReadyType window did not become available." >&2
    cat "$TMP_DIR/readytype.log" >&2 || true
    exit 1
fi

click_sidebar_button 2
sleep 0.4

SETTINGS_DUMP="$TMP_DIR/settings.txt"
for _ in {1..30}; do
    dump_scroll_area "$SETTINGS_DUMP"
    if grep -Fq "$MARKER" "$SETTINGS_DUMP"; then
        echo "ReadyType $APP_VERSION Common Words UI refresh check passed."
        exit 0
    fi
    sleep 0.2
done

echo "Common Words UI did not show the saved diagnostic term: $MARKER" >&2
echo "Dump file: $SETTINGS_DUMP" >&2
cat "$SETTINGS_DUMP" >&2 || true
exit 1
