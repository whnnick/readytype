# ReadyType 1.2.0 Black-Box Functional Check

Last updated: 2026-07-13. Current candidate build: `1.2.0 (80)`.

## Requirement Mapping and Status

| Product Area | Status | Evidence |
| --- | --- | --- |
| Main-window information architecture | Complete | Sidebar separates Usage Overview, Home, Common Words, Language & Output, Shortcuts, Speech Recognition, Permissions & Privacy, and About. |
| Light, Dark, Follow System | Complete | All three were checked in the real window; Follow System correctly remained dark on a dark system. |
| Dashboard | Automated and visual checks complete | Aggregate storage, same-day merge, streak, and clear tests pass; empty and populated states were visually checked. |
| Dashboard privacy | Complete | The persisted file contains daily numeric aggregates only; tests confirm transcript and output text are absent. |
| Simplified and Traditional Chinese | Complete | Simplified, Traditional, English/number preservation, and pre-delivery conversion tests pass. |
| High-accuracy status dot | Complete | Ready uses green while recording, processing, and error states retain priority. |
| Menu bar dismissal | User-accepted | Transient popover lifecycle, outside click, toggle, and Escape behavior were tightened; user reported no obvious issue. |
| Core voice-input pipeline | Automated and real-voice checks passed | Recording, recognition, AI processing, paste, and clipboard fallback tests pass; build 80 completed a real TextEdit voice-paste check. |
| Common Words end-to-end use | Automated and real-voice checks passed | Common Words feed fast recognition, high-accuracy Whisper, and AI cleanup; real Typeless and Reddit input preserved canonical spelling. |

## Verification Completed

- `swift test`: 357 executed, 14 skipped by real-service or environment conditions, 0 failures.
- `scripts/build-app.sh`: passed; App reports `1.2.0 (80)`.
- Contextual-vocabulary timeout test: fixed post-cancellation work; local fallback now completes in about 82-85ms.
- GitHub Release workflow: YAML parsing and release-gate tests pass; ZIP, DMG, and SHA-256 assets publish only when the version tag matches the App version.
- Compact HUD: a real recording-state full-screen capture passed; title, output mode, timer, waveform, and cancel guidance remain visible at the smaller size.
- `scripts/package-app.sh`, `scripts/package-dmg.sh`, and `hdiutil verify`: passed; ZIP and DMG were regenerated.
- Dashboard Light, Dark, and Follow System: checked in the real window.
- Populated Dashboard: completed-input count, voice duration, characters, and estimated time saved display real aggregates.
- Sensitive-data scan and `git diff --check`: run before the release commit.

## Final Manual Confirmation

1. Dashboard persistence was sampled and contains only dates, counts, voice seconds, and character totals, with no recognition or output text.
2. Menu dismissal retains the previously user-accepted implementation; build 80 does not change menu code and related automation still passes.
3. The Clear Statistics confirmation was opened and cancelled; all 18 local records remained and no deletion was performed.
4. Build 80 passed a real Typeless / Reddit voice test with canonical spelling and full-width Chinese punctuation in both recognition and final output.

## Release Blockers

1. Commit the final release documentation and wait for remote CI to pass.
2. Create the `v1.2.0` tag and verify the automatically generated GitHub Release assets.
