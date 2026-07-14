#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/ReadyType.app"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/ReadyType/ReadyType/Resources/ReadyTypeInfo.plist")"
OUT_DIR="${READYTYPE_VISUAL_ACCEPTANCE_DIR:-$ROOT_DIR/tmp/readytype-1.0.0-visual-acceptance/$(date +%Y%m%d-%H%M%S)}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/readytype-visual-acceptance.XXXXXX")"
CHECK_APP_DIR="$TMP_DIR/ReadyType.app"
OSASCRIPT_TIMEOUT_SECONDS="${OSASCRIPT_TIMEOUT_SECONDS:-8}"

mkdir -p "$OUT_DIR"

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
    quit_readytype_instances
    launchctl unsetenv READYTYPE_ENABLE_DEBUG_HUD >/dev/null 2>&1 || true
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

run_osascript() {
    local description="$1"
    shift

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
        /usr/bin/osascript "$@" >/dev/null || status=$?

    if [[ "$status" -eq 0 ]]; then
        return
    fi

    if [[ "$status" -eq 124 ]]; then
        echo "AppleScript timed out while checking: $description" >&2
        exit 1
    fi

    echo "AppleScript failed while checking: $description" >&2
    exit "$status"
}

wait_for_readytype_window() {
    for _ in {1..50}; do
        if window_id main >/dev/null 2>&1; then
            return
        fi
        sleep 0.2
    done

    echo "ReadyType window did not become available." >&2
    exit 1
}

cat > "$TMP_DIR/window-id.swift" <<'SWIFT'
import CoreGraphics
import Foundation

struct Candidate {
    let id: Int
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let area: Double
}

guard CommandLine.arguments.count == 2 else {
    exit(2)
}

let kind = CommandLine.arguments[1]
let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let candidates = info.compactMap { entry -> Candidate? in
    guard (entry[kCGWindowOwnerName as String] as? String) == "ReadyType",
          let id = entry[kCGWindowNumber as String] as? Int,
          let bounds = entry[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double,
          width > 40,
          height > 40
    else {
        return nil
    }

    let x = bounds["X"] as? Double ?? 0
    let y = bounds["Y"] as? Double ?? 0
    return Candidate(id: id, x: x, y: y, width: width, height: height, area: width * height)
}

let selected: Candidate?
switch kind {
case "main":
    selected = candidates
        .filter { $0.width >= 650 && $0.height >= 500 }
        .max { $0.area < $1.area }
case "hud":
    selected = candidates
        .filter { $0.width >= 360 && $0.width <= 500 && $0.height >= 48 && $0.height <= 100 }
        .min { $0.area < $1.area }
case "popover":
    selected = candidates
        .filter { $0.width >= 240 && $0.width <= 380 && $0.height >= 240 && $0.height <= 480 }
        .max { $0.area < $1.area }
default:
    selected = nil
}

guard let selected else {
    exit(1)
}

print("\(selected.id) \(Int(selected.x)) \(Int(selected.y)) \(Int(selected.width)) \(Int(selected.height))")
SWIFT

cat > "$TMP_DIR/post-hud-state.swift" <<'SWIFT'
import Foundation

guard CommandLine.arguments.count >= 2 else {
    fatalError("Expected state argument.")
}

let state = CommandLine.arguments[1]
let message = CommandLine.arguments.dropFirst(2).joined(separator: " ")
var userInfo: [String: String] = ["state": state]
if !message.isEmpty {
    userInfo["message"] = message
}

DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("readyTypeDebugHUDRequested"),
    object: nil,
    userInfo: userInfo,
    deliverImmediately: true
)

Thread.sleep(forTimeInterval: 0.3)
SWIFT

cat > "$TMP_DIR/click-point.swift" <<'SWIFT'
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 3,
      let x = Double(CommandLine.arguments[1]),
      let y = Double(CommandLine.arguments[2])
else {
    exit(2)
}

let point = CGPoint(x: x, y: y)
let source = CGEventSource(stateID: .hidSystemState)

CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
Thread.sleep(forTimeInterval: 0.05)
CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
Thread.sleep(forTimeInterval: 0.05)
CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
Thread.sleep(forTimeInterval: 0.12)
SWIFT

window_id() {
    CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache" swift "$TMP_DIR/window-id.swift" "$1"
}

post_hud_state() {
    CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache" swift "$TMP_DIR/post-hud-state.swift" "$@"
}

click_point() {
    CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache" swift "$TMP_DIR/click-point.swift" "$@"
}

capture_window() {
    local kind="$1"
    local name="$2"
    local geometry id x y width height
    geometry="$(window_id "$kind")"
    read -r id x y width height <<< "$geometry"
    if ! /usr/sbin/screencapture -x -l "$id" "$OUT_DIR/$name.png" 2>/dev/null; then
        if ! /usr/sbin/screencapture -x -R"${x},${y},${width},${height}" "$OUT_DIR/$name.png"; then
            echo "Unable to capture ReadyType $kind window. Check Screen Recording permission and the active display session." >&2
            exit 1
        fi
    fi
    validate_png "$OUT_DIR/$name.png"
}

validate_png() {
    local file="$1"

    if [[ ! -s "$file" ]]; then
        echo "Screenshot is empty: $file" >&2
        exit 1
    fi

    local size
    size="$(wc -c < "$file")"
    if [[ "$size" -lt 5000 ]]; then
        echo "Screenshot is unexpectedly small ($size bytes): $file" >&2
        exit 1
    fi

    /usr/bin/sips -g pixelWidth -g pixelHeight "$file" >/dev/null
}

click_sidebar_button() {
    local button_index="$1"

    if /usr/bin/osascript \
        -e "tell application \"System Events\" to tell process \"ReadyType\" to click button $button_index of group 1 of window 1" \
        >/dev/null 2>&1
    then
        return
    fi

    local geometry id x y width height click_x click_y
    geometry="$(window_id main)"
    read -r id x y width height <<< "$geometry"
    click_x=$((x + 98))
    click_y=$((y + 94 + (button_index - 1) * 38))
    click_point "$click_x" "$click_y"
}

if [[ ! -d "$APP_PATH" ]]; then
    echo "Missing app bundle: $APP_PATH" >&2
    echo "Run scripts/build-app.sh first." >&2
    exit 1
fi

quit_readytype_instances
ditto --norsrc "$APP_PATH" "$CHECK_APP_DIR"
xattr -cr "$CHECK_APP_DIR"
launchctl setenv READYTYPE_ENABLE_DEBUG_HUD 1
open -F -n "$CHECK_APP_DIR"
wait_for_readytype_window

click_sidebar_button 1
sleep 0.3
capture_window main "console"

click_sidebar_button 4
sleep 0.3
capture_window main "settings"

click_sidebar_button 7
sleep 0.3
capture_window main "permissions"

click_sidebar_button 8
sleep 0.3
capture_window main "about"

for state in recording transcribing processingAI pasted copiedFallback error; do
    case "$state" in
        recording) message="正在听，再次双击 Option 完成，Esc 取消" ;;
        transcribing) message="正在识别" ;;
        processingAI) message="正在整理" ;;
        pasted) message="已输入" ;;
        copiedFallback) message="已复制到剪贴板" ;;
        error) message="没有找到可粘贴的输入位置" ;;
    esac

    post_hud_state "$state" "$message"
    sleep 0.4
    capture_window hud "hud-$state"
done

post_hud_state idle
sleep 0.4

if /usr/bin/osascript -e 'tell application "System Events" to tell process "ReadyType" to click menu bar item 1 of menu bar 2' >/dev/null 2>&1; then
    sleep 0.5
    capture_window popover "menu-bar-popover"
else
    echo "Menu bar popover could not be opened through System Events." >&2
    exit 1
fi

echo "ReadyType $APP_VERSION visual acceptance screenshots written to $OUT_DIR"
