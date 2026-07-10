# ReadyType 1.1.0 Black-Box Functional Check

Last updated: 2026-07-11. Current release candidate: `1.1.0 (68)`.

## Requirement Mapping and Evidence

| Product area | Current status | Verification evidence |
| --- | --- | --- |
| Common words and confirmed suggestions | Complete | Store and learning tests pass; the isolated Common Words UI refresh gate passes without writing diagnostic entries to user data. |
| Chat, email, document, and English output | Automated acceptance complete | Five real DeepSeek checks pass: English chat, English email, natural personal chat, concise work chat, and document output without an unsupported closing. |
| Custom shortcuts and Esc | Complete | `GlobalShortcutServiceTests` passes 17/17; real double-press `Option` and `Esc` cancellation samples pass. |
| Automatic paste and clipboard fallback | Automated acceptance complete | `scripts/verify-1.2-textedit-paste.sh` passes. |
| High-accuracy speech-package state | Complete | Build 67 Settings verifies that Ready and Current Recommended Version are displayed independently; build 68 continues to pass real input. |
| High-accuracy speech-package updates | Automated and online checks complete | GitHub Raw manifest is reachable; online check succeeds; transaction tests cover persistence, rollback, and retaining the old package on failure. |

## Completed Verification

- `swift test`: 331 passed, 11 conditionally skipped, 0 failures.
- `scripts/build-app.sh`: passed; the release-candidate artifact is `1.1.0 (68)`.
- `scripts/package-app.sh`, `scripts/package-dmg.sh`, and `hdiutil verify dist/ReadyType.dmg`: passed; App, ZIP, and DMG all contain `1.1.0 (68)`.
- `scripts/verify-1.0.0-ui.sh`: passed on the final `1.1.0 (68)` build.
- `scripts/verify-1.0.0-common-words-ui.sh`: passed with an explicit temporary vocabulary file; user vocabulary remains untouched.
- `scripts/verify-1.2-textedit-paste.sh`: passed.
- `scripts/verify-1.2-real-ai-output.sh`: passed.
- `scripts/verify-1.2-api-error-paths.sh`: passed.
- Sensitive-information scan: passed; project `AGENTS.md` is not Git-tracked.

## Finding and Resolution in This Pass

- Real TextEdit input on build 67 showed an unsupported "谢谢大家" closing in document output.
- Cause: the non-email document prompt did not explicitly prohibit unsupported thanks, sign-offs, and closing language.
- Resolution: a shared non-email output-fidelity rule now covers generic, chat, note, document, and English translation output while preserving appropriate email closings.
- Recheck: the new real DeepSeek document case passes without an added closing.
- Build 68 real TextEdit recheck passes: automatic paste succeeded, technical terms were preserved, and "谢谢大家" was not added.

## Real-App Sample Results

- WeChat: polished output was natural and concise without an unsupported polite closing.
- `Esc`: active recording cancelled immediately and inserted no text.
- TextEdit: mixed Chinese-English input pasted automatically and no longer gained an unsupported closing.

## Non-Blocking Future Acceptance

- When ReadyType later recommends a different model, complete a real approximately 626 MiB update test. The remote recommendation currently matches the installed version, so no large download was artificially triggered.

## Release Blockers

1. Create and verify the GitHub `v1.1.0` Release, assets, and download links.
