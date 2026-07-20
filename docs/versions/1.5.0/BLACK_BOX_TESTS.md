# ReadyType 1.5.0 Black-box Acceptance

## Current Status

Navigation simplification, system automatic-punctuation configuration, and parallel-item punctuation in Polished Writing passed automated and real-interface acceptance.

| Requirement | Status | Evidence |
| --- | --- | --- |
| Simplified primary navigation | Complete | The sidebar shows only Home, Usage Overview, Common Words, and Settings. |
| Unified Settings entry | Complete | General, Speech Recognition, Shortcuts, Permissions & Privacy, and About are reachable. |
| Appearance relocation | Complete | System, Light, and Dark are available under General. |
| Onboarding routing | Complete | The high-accuracy speech-package prompt opens Speech Recognition inside Settings. |
| Automatic punctuation and parallel items | Complete | System dictation requests enable automatic punctuation. When a real-voice raw transcript contained no punctuation and a repeated fragment, Polished Writing correctly produced the equivalent of “discuss the budget, design draft, and release date. If the material is not ready, we will confirm tomorrow.” |
| Automated regression | Complete | Unit tests cover both the system request and cleanup prompt; `swift test`: 402 passed and 13 real external-environment tests skipped as designed; the app build and UI smoke gate passed. |

## Current Verified Artifact

- App: `dist/ReadyType.app`
- Version: `1.5.0 (91)`
- UI gate: all three primary destinations and all five Settings categories open with their core copy visible.

## Release Blocker

- Publish and verify the public `v1.5.0` Release, including `ReadyType.app.zip`, `ReadyType.dmg`, and `SHA256SUMS.txt`.
