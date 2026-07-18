#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/ReadyType.app"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/readytype-ui-check.XXXXXX")"
CHECK_APP_DIR="$TMP_DIR/ReadyType.app"
APP_VERSION="$(plutil -extract CFBundleShortVersionString raw "$ROOT_DIR/ReadyType/ReadyType/Resources/ReadyTypeInfo.plist")"
APP_BUILD="$(plutil -extract CFBundleVersion raw "$ROOT_DIR/ReadyType/ReadyType/Resources/ReadyTypeInfo.plist")"

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

main_window_exists() {
    osascript -e 'tell application "System Events" to tell process "ReadyType" to exists window "ReadyType"' \
        2>/dev/null | grep -Fxq true
}

wait_for_main_window() {
    for _ in {1..75}; do
        if main_window_exists; then
            return 0
        fi
        sleep 0.2
    done
    return 1
}

dump_page() {
    local index="$1"
    local output="$2"
    osascript -e "tell application \"System Events\" to tell process \"ReadyType\" to click button $index of group 1 of window \"ReadyType\"" >/dev/null
    sleep 0.25
    osascript -e 'tell application "System Events" to tell process "ReadyType" to get entire contents of scroll area 1 of group 1 of window "ReadyType"' > "$output"
}

dump_settings_page() {
    local index="$1"
    local output="$2"
    osascript -e 'tell application "System Events" to tell process "ReadyType" to click button 4 of group 1 of window "ReadyType"' >/dev/null
    sleep 0.2
    osascript -e "tell application \"System Events\" to tell process \"ReadyType\" to click button $index of scroll area 1 of group 1 of window \"ReadyType\"" >/dev/null
    sleep 0.25
    osascript -e 'tell application "System Events" to tell process "ReadyType" to get entire contents of scroll area 2 of group 1 of window "ReadyType"' > "$output"
}

require_text() {
    local file="$1"
    local expected="$2"
    if ! grep -Fq "$expected" "$file"; then
        echo "Missing expected UI text: $expected" >&2
        exit 1
    fi
}

[[ -d "$APP_DIR" ]] || { echo "Missing app bundle: $APP_DIR" >&2; exit 1; }

quit_readytype_instances
ditto --norsrc "$APP_DIR" "$CHECK_APP_DIR"
xattr -cr "$CHECK_APP_DIR"
open -F -n "$CHECK_APP_DIR"
sleep 0.5
osascript -e 'tell application "ReadyType" to activate' >/dev/null 2>&1 || true

if ! wait_for_main_window; then
    echo "ReadyType main window did not become available. Unlock the Mac and rerun this check." >&2
    exit 1
fi

HOME_DUMP="$TMP_DIR/home.txt"
DASHBOARD_DUMP="$TMP_DIR/dashboard.txt"
VOCABULARY_DUMP="$TMP_DIR/vocabulary.txt"
LANGUAGE_DUMP="$TMP_DIR/language.txt"
SHORTCUTS_DUMP="$TMP_DIR/shortcuts.txt"
SPEECH_DUMP="$TMP_DIR/speech.txt"
PERMISSIONS_DUMP="$TMP_DIR/permissions.txt"
ABOUT_DUMP="$TMP_DIR/about.txt"

dump_page 1 "$HOME_DUMP"
require_text "$HOME_DUMP" "说出你的想法"
require_text "$HOME_DUMP" "主快捷键"
require_text "$HOME_DUMP" "高精度语音包"
require_text "$HOME_DUMP" "最近结果"

dump_page 2 "$DASHBOARD_DUMP"
require_text "$DASHBOARD_DUMP" "使用概览"
require_text "$DASHBOARD_DUMP" "最近 14 天"
require_text "$DASHBOARD_DUMP" "统计只保存在这台 Mac"

dump_page 3 "$VOCABULARY_DUMP"
require_text "$VOCABULARY_DUMP" "常用词有什么用？"
require_text "$VOCABULARY_DUMP" "添加一个"
require_text "$VOCABULARY_DUMP" "一次添加多个"

dump_settings_page 1 "$LANGUAGE_DUMP"
require_text "$LANGUAGE_DUMP" "通用"
require_text "$LANGUAGE_DUMP" "外观"
require_text "$LANGUAGE_DUMP" "中文文字"
require_text "$LANGUAGE_DUMP" "DeepSeek 密钥"
require_text "$LANGUAGE_DUMP" "输入到当前 App"

dump_settings_page 3 "$SHORTCUTS_DUMP"
require_text "$SHORTCUTS_DUMP" "开始说话快捷键"
require_text "$SHORTCUTS_DUMP" "Esc 取消保持不变"
require_text "$SHORTCUTS_DUMP" "输出体验"

dump_settings_page 2 "$SPEECH_DUMP"
require_text "$SPEECH_DUMP" "语音识别"
require_text "$SPEECH_DUMP" "当前识别方式"
require_text "$SPEECH_DUMP" "安装高精度语音包后"
require_text "$SPEECH_DUMP" "高精度语音包约 626 MiB"

dump_settings_page 4 "$PERMISSIONS_DUMP"
require_text "$PERMISSIONS_DUMP" "授权状态"
require_text "$PERMISSIONS_DUMP" "隐私说明"
require_text "$PERMISSIONS_DUMP" "不会发送语音、文字内容"

dump_settings_page 5 "$ABOUT_DUMP"
require_text "$ABOUT_DUMP" "关于 ReadyType"
require_text "$ABOUT_DUMP" "版本 $APP_VERSION"
require_text "$ABOUT_DUMP" "构建 $APP_BUILD"
require_text "$ABOUT_DUMP" "默认不保存完整转写历史"

echo "ReadyType $APP_VERSION ($APP_BUILD) UI check passed."
