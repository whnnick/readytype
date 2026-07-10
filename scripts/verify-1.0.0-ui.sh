#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/ReadyType.app"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/ReadyType/ReadyType/Resources/ReadyTypeInfo.plist")"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/readytype-1.0.0-ui-check.XXXXXX")"
CHECK_APP_DIR="$TMP_DIR/ReadyType.app"

OSASCRIPT_TIMEOUT_SECONDS="${OSASCRIPT_TIMEOUT_SECONDS:-8}"

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
            -e 'tell application "System Events" to tell process "ReadyType" to count windows'

        if grep -Eq '^[1-9][0-9]*$' "$output_file"; then
            return 0
        fi
        sleep 0.2
    done

    return 1
}

dump_scroll_area() {
    local output_file="$1"
    run_osascript "ReadyType visible scroll area" "$output_file" \
        -e 'tell application "System Events" to tell process "ReadyType" to get properties of UI elements of scroll area 1 of group 1 of window 1'
}

dump_radio_buttons() {
    local group_index="$1"
    local output_file="$2"
    run_osascript "ReadyType radio group $group_index" "$output_file" \
        -e "tell application \"System Events\" to tell process \"ReadyType\" to get properties of radio buttons of radio group $group_index of scroll area 1 of group 1 of window 1"
}

click_sidebar_button() {
    local button_index="$1"
    local output_file="$TMP_DIR/click-$button_index.txt"
    run_osascript "ReadyType sidebar button $button_index" "$output_file" \
        -e "tell application \"System Events\" to tell process \"ReadyType\" to click button $button_index of group 1 of window 1"
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

if [[ ! -d "$APP_DIR" ]]; then
    echo "Missing app bundle: $APP_DIR" >&2
    echo "Run scripts/build-app.sh first." >&2
    exit 1
fi

quit_readytype_instances
ditto --norsrc "$APP_DIR" "$CHECK_APP_DIR"
xattr -cr "$CHECK_APP_DIR"
open -F -n "$CHECK_APP_DIR" --args -voiceShortcutTrigger doubleOption -voiceShortcutDoublePressInterval 0.45

if ! wait_for_readytype_window; then
    open "$CHECK_APP_DIR" --args -voiceShortcutTrigger doubleOption -voiceShortcutDoublePressInterval 0.45
fi

if ! wait_for_readytype_window; then
    echo "ReadyType window did not become available." >&2
    exit 1
fi

CONSOLE_DUMP="$TMP_DIR/console.txt"
OUTPUT_METHOD_DUMP="$TMP_DIR/output-methods.txt"
SCENARIO_DUMP="$TMP_DIR/scenarios.txt"
SETTINGS_DUMP="$TMP_DIR/settings.txt"
PERMISSIONS_DUMP="$TMP_DIR/permissions.txt"
ABOUT_DUMP="$TMP_DIR/about.txt"

click_sidebar_button 1
sleep 0.3
dump_scroll_area "$CONSOLE_DUMP"
dump_radio_buttons 1 "$OUTPUT_METHOD_DUMP"
dump_radio_buttons 2 "$SCENARIO_DUMP"

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

click_sidebar_button 2
sleep 0.3
dump_scroll_area "$SETTINGS_DUMP"

require_text "$SETTINGS_DUMP" "设置"
require_text "$SETTINGS_DUMP" "识别方式"
require_text "$SETTINGS_DUMP" "当前识别方式"
require_text "$SETTINGS_DUMP" "DeepSeek 连接"
require_text "$SETTINGS_DUMP" "默认输出方式"
require_text "$SETTINGS_DUMP" "服务地址"
require_text "$SETTINGS_DUMP" "模型名称"
require_text "$SETTINGS_DUMP" "DeepSeek 密钥"
require_text "$SETTINGS_DUMP" "测试连接"
require_text "$SETTINGS_DUMP" "尚未测试"
require_text "$SETTINGS_DUMP" "填写或保存 DeepSeek 连接信息后，可以先测试连接。"
require_text "$SETTINGS_DUMP" "常用词"
require_text "$SETTINGS_DUMP" "批量导入"
require_text "$SETTINGS_DUMP" "一行一个词"
require_text "$SETTINGS_DUMP" "开始说话快捷键"
require_text "$SETTINGS_DUMP" "保存后立即生效；Esc 取消保持不变。"
require_text "$SETTINGS_DUMP" "菜单栏浮窗可快速切换直接转文字、整理成文、翻译成英文、写给 AI。"
require_text "$SETTINGS_DUMP" "高精度语音包保存在"

click_sidebar_button 3
sleep 0.3
dump_scroll_area "$PERMISSIONS_DUMP"

require_text "$PERMISSIONS_DUMP" "权限"
require_text "$PERMISSIONS_DUMP" "授权状态"
require_text "$PERMISSIONS_DUMP" "麦克风"
require_text "$PERMISSIONS_DUMP" "语音识别"
require_text "$PERMISSIONS_DUMP" "辅助功能"
require_text "$PERMISSIONS_DUMP" "隐私说明"
require_text "$PERMISSIONS_DUMP" "不保存完整转写历史"
require_text "$PERMISSIONS_DUMP" "直接转文字不调用 DeepSeek"

click_sidebar_button 4
sleep 0.3
dump_scroll_area "$ABOUT_DUMP"

require_text "$ABOUT_DUMP" "关于 ReadyType"
require_text "$ABOUT_DUMP" "版本 $APP_VERSION"
require_text "$ABOUT_DUMP" "高精度语音包保存在"
require_text "$ABOUT_DUMP" "以后需要更新时可重新下载"
require_text "$ABOUT_DUMP" "下载后会在后台准备"

echo "ReadyType $APP_VERSION UI text check passed."
