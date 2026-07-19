# ReadyType 1.5.0 Black-box Acceptance

## Current Status

Navigation simplification and the system automatic-punctuation configuration passed automated and real-interface acceptance. Natural-speech punctuation still requires a manual dictation retest.

| Requirement | Status | Evidence |
| --- | --- | --- |
| Simplified primary navigation | Complete | The sidebar shows only Home, Usage Overview, Common Words, and Settings. |
| Unified Settings entry | Complete | General, Speech Recognition, Shortcuts, Permissions & Privacy, and About are reachable. |
| Appearance relocation | Complete | System, Light, and Dark are available under General. |
| Onboarding routing | Complete | The high-accuracy speech-package prompt opens Speech Recognition inside Settings. |
| Fast-recognition automatic punctuation | Automated complete, manual pending | System dictation requests enable automatic punctuation, with unit coverage for dictation mode, contextual terms, and punctuation configuration; natural Chinese dictation still needs a semantic-punctuation retest. |
| Automated regression | Complete | `swift test`: 401 passed and 13 real external-environment tests skipped as designed; `scripts/build-app.sh` and `scripts/verify-ui.sh` passed. |

## Current Verified Artifact

- App: `dist/ReadyType.app`
- Version: `1.5.0 (90)`
- UI gate: all three primary destinations and all five Settings categories open with their core copy visible.
