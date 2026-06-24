#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/ReadyType.app"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/readytype-ui-check.XXXXXX")"
CHECK_APP_DIR="$TMP_DIR/ReadyType.app"

quit_readytype_instances() {
    osascript -e 'tell application "ReadyType" to quit' >/dev/null 2>&1 || true

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
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

wait_for_readytype_window() {
    for _ in {1..50}; do
        if osascript -e 'tell application "System Events" to tell process "ReadyType" to count windows' 2>/dev/null | grep -Eq '^[1-9][0-9]*$'; then
            return 0
        fi
        sleep 0.2
    done

    return 1
}

if [[ ! -d "$APP_DIR" ]]; then
    echo "Missing app bundle: $APP_DIR" >&2
    echo "Run scripts/build-app.sh first." >&2
    exit 1
fi

quit_readytype_instances
ditto --norsrc "$APP_DIR" "$CHECK_APP_DIR"
xattr -cr "$CHECK_APP_DIR"
open -F -n "$CHECK_APP_DIR"

if ! wait_for_readytype_window; then
    open "$CHECK_APP_DIR"
fi

if ! wait_for_readytype_window; then
    echo "ReadyType window did not become available." >&2
    exit 1
fi

dump_scroll_area() {
    osascript -e 'tell application "System Events" to tell process "ReadyType" to get properties of UI elements of scroll area 1 of group 1 of window 1'
}

dump_radio_buttons() {
    local group_index="$1"
    osascript -e "tell application \"System Events\" to tell process \"ReadyType\" to get properties of radio buttons of radio group $group_index of scroll area 1 of group 1 of window 1"
}

require_text() {
    local file="$1"
    local expected="$2"

    if ! grep -Fq "$expected" "$file"; then
        echo "Missing expected UI text: $expected" >&2
        echo "Dump file: $file" >&2
        exit 1
    fi
}

CONSOLE_DUMP="$TMP_DIR/console.txt"
OUTPUT_METHOD_DUMP="$TMP_DIR/output-methods.txt"
SCENARIO_DUMP="$TMP_DIR/scenarios.txt"
SETTINGS_DUMP="$TMP_DIR/settings.txt"

osascript -e 'tell application "System Events" to tell process "ReadyType" to click button 1 of group 1 of window 1' >/dev/null 2>&1 || true
sleep 0.3
dump_scroll_area > "$CONSOLE_DUMP"
dump_radio_buttons 1 > "$OUTPUT_METHOD_DUMP"
dump_radio_buttons 2 > "$SCENARIO_DUMP"

require_text "$CONSOLE_DUMP" "ReadyType 控制台"
require_text "$CONSOLE_DUMP" "输出方式"
require_text "$CONSOLE_DUMP" "写作场景"
require_text "$CONSOLE_DUMP" "Option x2"
require_text "$CONSOLE_DUMP" "最近结果"
require_text "$OUTPUT_METHOD_DUMP" "直接转文字"
require_text "$OUTPUT_METHOD_DUMP" "整理成文"
require_text "$OUTPUT_METHOD_DUMP" "翻译成英文"
require_text "$OUTPUT_METHOD_DUMP" "写给 AI"
require_text "$SCENARIO_DUMP" "自动"
require_text "$SCENARIO_DUMP" "通用"
require_text "$SCENARIO_DUMP" "邮件"
require_text "$SCENARIO_DUMP" "聊天"
require_text "$SCENARIO_DUMP" "笔记"
require_text "$SCENARIO_DUMP" "AI 工具"
require_text "$SCENARIO_DUMP" "文档"

osascript -e 'tell application "System Events" to tell process "ReadyType" to click button 2 of group 1 of window 1' >/dev/null
sleep 0.3
dump_scroll_area > "$SETTINGS_DUMP"

require_text "$SETTINGS_DUMP" "设置"
require_text "$SETTINGS_DUMP" "默认输出方式"
require_text "$SETTINGS_DUMP" "Base URL"
require_text "$SETTINGS_DUMP" "模型"
require_text "$SETTINGS_DUMP" "API Key"
require_text "$SETTINGS_DUMP" "尚未测试"
require_text "$SETTINGS_DUMP" "填写或保存 DeepSeek 配置后，可以先测试连接。"
require_text "$SETTINGS_DUMP" "菜单栏浮窗可快速切换直接转文字、整理成文、翻译成英文、写给 AI。"

echo "ReadyType 1.2 UI text check passed."
