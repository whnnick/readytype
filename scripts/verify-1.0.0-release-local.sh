#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' ReadyType/ReadyType/Resources/ReadyTypeInfo.plist)"

SWIFTPM_CACHE_DIR="$ROOT_DIR/.build/swiftpm-cache"
SWIFTPM_CONFIG_DIR="$ROOT_DIR/.build/swiftpm-config"
SWIFTPM_SECURITY_DIR="$ROOT_DIR/.build/swiftpm-security"
CLANG_MODULE_CACHE_DIR="$ROOT_DIR/.build/clang-module-cache"

mkdir -p "$SWIFTPM_CACHE_DIR" "$SWIFTPM_CONFIG_DIR" "$SWIFTPM_SECURITY_DIR" "$CLANG_MODULE_CACHE_DIR"

export CLANG_MODULE_CACHE_PATH="$CLANG_MODULE_CACHE_DIR"

RUN_REAL_AI="${RUN_REAL_AI:-0}"
RUN_API_FAILURES="${RUN_API_FAILURES:-0}"
RUN_TEXTEDIT_PASTE="${RUN_TEXTEDIT_PASTE:-0}"
RUN_UI_ACCEPTANCE="${RUN_UI_ACCEPTANCE:-0}"
RUN_COMMON_WORDS_UI="${RUN_COMMON_WORDS_UI:-0}"
RUN_VISUAL_ACCEPTANCE="${RUN_VISUAL_ACCEPTANCE:-0}"
RUN_LOCAL_SPEECH_MODEL="${RUN_LOCAL_SPEECH_MODEL:-0}"
RUN_ASR_METRICS="${RUN_ASR_METRICS:-0}"
ASR_METRICS_FILE="${ASR_METRICS_FILE:-docs/versions/1.0.0/plans/readytype-1.0.0-asr-metrics-record.local.json}"

log_step() {
  printf "\n==> %s\n" "$1"
}

log_step "swift test"
swift test \
  --disable-sandbox \
  --cache-path "$SWIFTPM_CACHE_DIR" \
  --config-path "$SWIFTPM_CONFIG_DIR" \
  --security-path "$SWIFTPM_SECURITY_DIR" \
  --manifest-cache local

log_step "scripts/benchmark-1.0.0-contextual-vocabulary.sh"
scripts/benchmark-1.0.0-contextual-vocabulary.sh

log_step "scripts/build-app.sh"
scripts/build-app.sh

log_step "strict app bundle code-signing check"
TMP_APP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/readytype-codesign.XXXXXX")"
trap 'rm -rf "$TMP_APP_DIR"' EXIT
ditto --norsrc dist/ReadyType.app "$TMP_APP_DIR/ReadyType.app"
xattr -cr "$TMP_APP_DIR/ReadyType.app"
codesign --verify --deep --strict --verbose=2 "$TMP_APP_DIR/ReadyType.app"

log_step "scripts/package-app.sh"
scripts/package-app.sh

log_step "scripts/package-dmg.sh"
scripts/package-dmg.sh

log_step "plutil"
plutil -lint ReadyType/ReadyType/Resources/ReadyTypeInfo.plist

log_step "git diff --check"
git diff --check

log_step "user-facing recognition UI technical-name scan"
if rg -n "Apple Speech|Whisper|WhisperKit|whisper.cpp|本地 Whisper" \
  ReadyType/ReadyType/App \
  ReadyType/ReadyType/Settings \
  ReadyType/ReadyType/Permissions \
  ReadyType/ReadyType/UI; then
  echo "User-facing UI still exposes technical recognition engine names." >&2
  exit 1
fi

log_step "sensitive information scan"
if [[ -n "${SECRET_PATTERNS_OVERRIDE:-}" ]]; then
  secret_pattern="$SECRET_PATTERNS_OVERRIDE"
else
  secret_patterns=(
    'sk-[A-Za-z0-9_-]{10,}'
    'api[_-]?key[[:space:]]*='
    'API_KEY[[:space:]]*='
    'Authorization:'" Bearer"
    'BEGIN (RSA|OPENSSH|PRIVATE) KEY'
    'xox[baprs]-'
    'ghp_[A-Za-z0-9_]{20,}'
    'github_'"pat_"
  )
  secret_pattern="$(IFS='|'; echo "${secret_patterns[*]}")"
fi

if rg -n "$secret_pattern" . --hidden -g '!/.git' -g '!/.build' -g '!dist'; then
  echo "Sensitive-information scan found matches. Review them before release." >&2
  exit 1
fi

if [[ "$RUN_REAL_AI" == "1" ]]; then
  log_step "scripts/verify-1.2-real-ai-output.sh"
  scripts/verify-1.2-real-ai-output.sh
else
  log_step "skipping real DeepSeek acceptance"
  echo "Set RUN_REAL_AI=1 to run scripts/verify-1.2-real-ai-output.sh."
fi

if [[ "$RUN_API_FAILURES" == "1" ]]; then
  log_step "scripts/verify-1.2-api-error-paths.sh"
  scripts/verify-1.2-api-error-paths.sh
else
  log_step "skipping real API failure acceptance"
  echo "Set RUN_API_FAILURES=1 to run scripts/verify-1.2-api-error-paths.sh."
fi

if [[ "$RUN_TEXTEDIT_PASTE" == "1" ]]; then
  log_step "scripts/verify-1.2-textedit-paste.sh"
  scripts/verify-1.2-textedit-paste.sh
else
  log_step "skipping TextEdit paste acceptance"
  echo "Set RUN_TEXTEDIT_PASTE=1 to run scripts/verify-1.2-textedit-paste.sh."
fi

if [[ "$RUN_UI_ACCEPTANCE" == "1" ]]; then
  log_step "scripts/verify-1.0.0-ui.sh"
  scripts/verify-1.0.0-ui.sh
else
  log_step "skipping GUI UI text acceptance"
  echo "Set RUN_UI_ACCEPTANCE=1 to run scripts/verify-1.0.0-ui.sh."
fi

if [[ "$RUN_COMMON_WORDS_UI" == "1" ]]; then
  log_step "scripts/verify-1.0.0-common-words-ui.sh"
  scripts/verify-1.0.0-common-words-ui.sh
else
  log_step "skipping Common Words UI refresh acceptance"
  echo "Set RUN_COMMON_WORDS_UI=1 to verify Common Words saved from the app refresh Settings."
fi

if [[ "$RUN_VISUAL_ACCEPTANCE" == "1" ]]; then
  log_step "scripts/verify-1.0.0-visual-acceptance.sh"
  scripts/verify-1.0.0-visual-acceptance.sh
else
  log_step "skipping visual screenshot acceptance"
  echo "Set RUN_VISUAL_ACCEPTANCE=1 to capture main-window, HUD, and menu-bar screenshots."
fi

if [[ "$RUN_LOCAL_SPEECH_MODEL" == "1" ]]; then
  log_step "scripts/verify-1.0.0-local-speech-model.sh"
  scripts/verify-1.0.0-local-speech-model.sh
else
  log_step "skipping real local speech-package acceptance"
  echo "Set RUN_LOCAL_SPEECH_MODEL=1 to download or reuse the real high-accuracy speech package."
fi

if [[ "$RUN_ASR_METRICS" == "1" ]]; then
  log_step "scripts/evaluate-1.0.0-asr-metrics.swift"
  if [[ ! -f "$ASR_METRICS_FILE" ]]; then
    echo "ASR metrics file not found: $ASR_METRICS_FILE" >&2
    echo "Copy docs/versions/1.0.0/plans/readytype-1.0.0-asr-metrics-template.json to a .local.json file and fill real microphone results." >&2
    exit 1
  fi
  scripts/evaluate-1.0.0-asr-metrics.swift --strict "$ASR_METRICS_FILE"
else
  log_step "skipping real ASR metrics acceptance"
  echo "Set RUN_ASR_METRICS=1 and ASR_METRICS_FILE=... to evaluate real microphone CER, language, latency, and resource metrics."
fi

printf "\nReadyType %s local release gate passed.\n" "$APP_VERSION"
