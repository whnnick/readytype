# ReadyType 1.1.0

ReadyType 1.1.0 focuses on productizing real-world input quality: common words, confirmed learning suggestions, app-aware tone, custom shortcuts, and high-accuracy speech-package status.

## Documents

- [Requirements](./REQUIREMENTS.md)
- [Implementation Plan](./PLAN.md)

## Current Assessment

ReadyType 1.0.0 already includes part of the foundation: common-word storage, import, confirmed suggestions, shortcut configuration, and high-accuracy speech-package status display. Version 1.1.0 should not rebuild these foundations. It should make them clearer, more stable, and easier for regular users to understand.

## Current Progress

- Added a Companies / Organizations common-word category.
- Changed the default category label from a generic wording to "Other".
- Reworded common-word suggestion copy to avoid implying silent memory or training.
- Common-word suggestions now filter overlong candidates and spoken stop words to avoid saving full sentences, private body text, or noise such as "OK", "好了", or "完成".
- Added personal-chat and work-chat tone rules so WeChat/chat output does not add unsupported overly polite endings.
- Tightened English email output constraints for recipients, numbered lists, and subject lines: when the user says to email a named person, the greeting must preserve the recipient, and subjects are not added unless requested.
- Reviewed custom shortcuts: double-press `Option` remains the default, custom triggers apply immediately, and `Esc` cancellation remains independent.
- Added a separate high-accuracy speech-package version status covering not checked, checking, missing, current bundled version, update available, and temporarily unable to check.
- `dist/ReadyType.dmg` can be generated and passes `hdiutil verify`; `hdiutil create` must run outside the sandbox.

Verification:
- `swift test --filter UserVocabularyStoreTests`: 11 tests passed.
- `swift test --filter UserVocabularyLearningServiceTests`: 5 tests passed.
- `swift test --filter PromptTemplatesTests`: 15 tests passed.
- `swift test --filter OutputScenarioTests`: 11 tests passed.
- `swift test --filter GlobalShortcutServiceTests`: 17 tests passed.
- `swift test --filter SettingsViewModelTests`: 20 tests passed.
- `swift test --filter LocalSpeechModelUpdateCheckerTests`: 4 tests passed.
- `swift test`: 320 tests passed, 10 tests skipped.
- `scripts/build-app.sh`: passed.
- `scripts/package-dmg.sh`: passed and generated `dist/ReadyType.dmg`.
- `scripts/verify-1.0.0-release-local.sh`: passed, including unit tests, contextual-vocabulary performance, build, zip, DMG, `plutil`, `git diff --check`, user-facing recognition wording scan, and sensitive-information scan.
- `scripts/verify-1.0.0-ui.sh`: passed.
- `scripts/verify-1.2-textedit-paste.sh`: passed.
- `scripts/verify-1.0.0-common-words-ui.sh`: passed.
- `scripts/verify-1.0.0-visual-acceptance.sh`: passed; screenshots were written to `tmp/readytype-1.0.0-visual-acceptance/20260704-170909`.
- `scripts/verify-1.2-real-ai-output.sh`: passed; covered real DeepSeek output for English email, English chat, personal chat, and work chat.
- `scripts/verify-1.2-api-error-paths.sh`: passed; covered invalid key, invalid model, timeout, and unreachable base URL.
- After the English-email prompt fix, `swift test`: 320 tests passed, 10 tests skipped.
- After the English-email prompt fix, `scripts/build-app.sh`, `scripts/package-app.sh`, `scripts/package-dmg.sh`, and `hdiutil verify dist/ReadyType.dmg`: passed.

Real-environment gates not covered yet:
- `RUN_LOCAL_SPEECH_MODEL=1 scripts/verify-1.0.0-release-local.sh`: requires downloading or reusing the real high-accuracy speech package.
- `RUN_ASR_METRICS=1 scripts/verify-1.0.0-release-local.sh`: requires a real microphone ASR metrics file.
- Real-app regression in WeChat, browsers, email/document tools, and AI tools still needs a final sample pass before release.

## Development Order

1. Productize Common Words: complete.
2. Tighten confirmed learning suggestions: complete.
3. Improve app-aware tone: covered by automated tests, pending real-app regression.
4. Review custom shortcut experience: covered by automated tests, pending real-app regression.
5. Improve high-accuracy speech-package status and update prompts: covered by automated tests, pending real-app regression.
6. Update docs, tests, and release preparation: local release gate passed; pending real-environment gates and final release decision.
