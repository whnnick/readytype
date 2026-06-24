#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${DEEPSEEK_API_KEY:-}" ]]; then
  if security find-generic-password -s com.readytype.app -a deepseek >/dev/null 2>&1; then
    echo "Using saved ReadyType Keychain API key for real DeepSeek acceptance."
  else
    echo "Skipping real DeepSeek acceptance: set DEEPSEEK_API_KEY or save the API key in ReadyType settings."
    exit 0
  fi
else
  echo "Using DEEPSEEK_API_KEY for real DeepSeek acceptance."
fi

READYTYPE_RUN_REAL_DEEPSEEK_ACCEPTANCE=1 swift test --filter RealDeepSeekOutputAcceptanceTests
