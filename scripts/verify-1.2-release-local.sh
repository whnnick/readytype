#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RUN_REAL_AI="${RUN_REAL_AI:-0}"
RUN_API_FAILURES="${RUN_API_FAILURES:-0}"
RUN_TEXTEDIT_PASTE="${RUN_TEXTEDIT_PASTE:-0}"

log_step() {
  printf "\n==> %s\n" "$1"
}

log_step "swift test"
swift test

log_step "scripts/build-app.sh"
scripts/build-app.sh

log_step "app bundle strict code-signing check"
TMP_APP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/readytype-codesign.XXXXXX")"
trap 'rm -rf "$TMP_APP_DIR"' EXIT
ditto --norsrc dist/ReadyType.app "$TMP_APP_DIR/ReadyType.app"
xattr -cr "$TMP_APP_DIR/ReadyType.app"
codesign --verify --deep --strict --verbose=2 "$TMP_APP_DIR/ReadyType.app"

log_step "scripts/package-app.sh"
scripts/package-app.sh

log_step "scripts/verify-1.2-ui.sh"
scripts/verify-1.2-ui.sh

log_step "plutil"
plutil -lint ReadyType/ReadyType/Resources/ReadyTypeInfo.plist

log_step "git diff --check"
git diff --check

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

printf "\nReadyType 1.2 local release gate passed.\n"
