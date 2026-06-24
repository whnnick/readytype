#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SWIFTPM_CACHE_DIR="$ROOT_DIR/.build/swiftpm-cache"
SWIFTPM_CONFIG_DIR="$ROOT_DIR/.build/swiftpm-config"
SWIFTPM_SECURITY_DIR="$ROOT_DIR/.build/swiftpm-security"
CLANG_MODULE_CACHE_DIR="$ROOT_DIR/.build/clang-module-cache"

mkdir -p "$SWIFTPM_CACHE_DIR" "$SWIFTPM_CONFIG_DIR" "$SWIFTPM_SECURITY_DIR" "$CLANG_MODULE_CACHE_DIR"

export CLANG_MODULE_CACHE_PATH="$CLANG_MODULE_CACHE_DIR"

printf "Running ReadyType 1.0.0 contextual vocabulary latency benchmark...\n"
swift test \
  --disable-sandbox \
  --cache-path "$SWIFTPM_CACHE_DIR" \
  --config-path "$SWIFTPM_CONFIG_DIR" \
  --security-path "$SWIFTPM_SECURITY_DIR" \
  --manifest-cache local \
  --filter ContextualVocabularyLatencyBudgetTests
