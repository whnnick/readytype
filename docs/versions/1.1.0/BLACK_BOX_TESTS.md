# ReadyType 1.1.0 Black-Box Functional Check

Last updated: 2026-07-10. Current build: `1.0.0 (67)`; `1.1.0` is not released yet.

## Requirement Mapping and Evidence

| Product area | Current status | Verification evidence |
| --- | --- | --- |
| Common words and confirmed suggestions | Complete | `UserVocabularyStoreTests` and `UserVocabularyLearningServiceTests` pass; Settings retains only explicitly added content. |
| Chat, email, and English output | Automated acceptance complete | Four real DeepSeek checks pass: English chat, English email, natural personal chat, and concise work chat. |
| Custom shortcuts and Esc | Automated acceptance complete | `GlobalShortcutServiceTests` passes 17/17; real modifier-only key presses still need manual confirmation. |
| Automatic paste and clipboard fallback | Automated acceptance complete | `scripts/verify-1.2-textedit-paste.sh` passes. |
| High-accuracy speech-package state | Complete | Build 67 Settings verifies that Ready and Current Recommended Version are displayed independently. |
| High-accuracy speech-package updates | Automated and online checks complete | GitHub Raw manifest is reachable; online check succeeds; transaction tests cover persistence, rollback, and retaining the old package on failure. |

## Completed Verification

- `swift test`: 328 passed, 13 conditionally skipped, 0 failures.
- `scripts/build-app.sh`: passed; artifact is `1.0.0 (67)`.
- `scripts/package-app.sh`, `scripts/package-dmg.sh`, and `hdiutil verify dist/ReadyType.dmg`: passed.
- `scripts/verify-1.0.0-ui.sh`: passed on build 66; build 67's online speech-package check was retested in the real UI.
- `scripts/verify-1.2-textedit-paste.sh`: passed.
- `scripts/verify-1.2-real-ai-output.sh`: passed.
- `scripts/verify-1.2-api-error-paths.sh`: passed.
- Sensitive-information scan: passed; project `AGENTS.md` is not Git-tracked.

## Real-Environment Acceptance Still Required

- In WeChat, Notes, a browser, and an email or document tool, use real microphone input to sample double-press `Option` start/finish, `Esc` cancellation, and automatic paste.
- Confirm that WeChat chat output remains natural and concise, without unsupported polite endings such as "thanks" or "please".
- With the real high-accuracy speech package, test one long sentence and one mixed Chinese-English sentence, recording first-use and post-prewarm wait time.
- When ReadyType later recommends a different model, complete a real approximately 626 MiB update test. The remote recommendation currently matches the installed version, so no large download was artificially triggered.

## Release Blockers

1. Complete and record the real microphone multi-app sample pass above.
2. Bump the short version from `1.0.0` to `1.1.0`, then rebuild the DMG and ZIP.
3. Complete final sensitive-information, remote Release artifact, and download-link checks.
