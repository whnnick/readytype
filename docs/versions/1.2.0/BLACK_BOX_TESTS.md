# ReadyType 1.2.0 Black-Box Functional Check

Last updated: 2026-07-12. Current candidate build: `1.2.0 (73)`.

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
| Core voice-input pipeline | No automated regression | Recording, recognition, AI processing, paste, and clipboard fallback tests continue to pass. |

## Verification Completed

- `swift test`: 347 executed, 14 skipped by real-service or environment conditions, 0 failures.
- `scripts/build-app.sh`: passed; App reports `1.2.0 (73)`.
- `scripts/package-app.sh`, `scripts/package-dmg.sh`, and `hdiutil verify`: passed; ZIP and DMG were regenerated.
- Dashboard Light, Dark, and Follow System: checked in the real window.
- Populated Dashboard: completed-input count, voice duration, characters, and estimated time saved display real aggregates.
- Sensitive-data scan and `git diff --check`: run before the release commit.

## Manual Confirmation Remaining

1. Complete one real voice input in final build 73 and confirm all four aggregates update once while no text is persisted.
2. Reconfirm status-item toggle, outside click, and Escape dismissal in final build 73.
3. Confirm the Clear Statistics dialog and result; automated UI must not delete the user's local aggregate data.

## Release Blockers

1. Complete the three manual confirmations above.
2. Update 1.2.0 release notes, create the tag, and verify GitHub assets.
