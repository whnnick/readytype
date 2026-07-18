# ReadyType 1.5.0 Black-box Acceptance

## Current Status

The first navigation-simplification milestone passed automated and real-interface acceptance.

| Requirement | Status | Evidence |
| --- | --- | --- |
| Simplified primary navigation | Complete | The sidebar shows only Home, Usage Overview, Common Words, and Settings. |
| Unified Settings entry | Complete | General, Speech Recognition, Shortcuts, Permissions & Privacy, and About are reachable. |
| Appearance relocation | Complete | System, Light, and Dark are available under General. |
| Onboarding routing | Complete | The high-accuracy speech-package prompt opens Speech Recognition inside Settings. |
| Automated regression | Complete | `swift test`: 400 passed and 13 real external-environment tests skipped as designed; `scripts/build-app.sh` and `scripts/verify-ui.sh` passed. |

## Current Verified Artifact

- App: `dist/ReadyType.app`
- Version: `1.5.0 (89)`
- UI gate: all three primary destinations and all five Settings categories open with their core copy visible.
