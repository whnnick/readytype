# ReadyType 1.5.1 Black-box Acceptance

## Current Status

Recognition and output-pipeline improvements passed the local and remote release gates. `v1.5.1` is publicly released; selected-text voice actions remain unavailable.

| Requirement | Status | Evidence |
| --- | --- | --- |
| Long-form recognition concurrency | Complete | Regression coverage verifies the eight-second boundary, concurrent start, three-second budget, and reuse of completed fast results. |
| Bounded quality selection | Complete | Engine-specific quality metadata and complete-candidate selection are covered without cross-engine raw-score comparison. |
| Contextual vocabulary and AI latency | Complete | Tests cover bounded canonical terms, general spelling rules, disabled thinking, bounded output, and split latency reporting. |
| Automated and packaging gates | Complete | The full 439-test suite passed with 14 external-environment tests skipped as designed. The official build, signature checks, UI gate, sensitive-information scan, ZIP, DMG, and checksum verification passed locally and in GitHub Actions. |

## Verified Candidate

- App: `dist/ReadyType.app`
- Version: `1.5.1 (96)`

## Release Verification

- GitHub Release workflow [31860207850](https://github.com/whnnick/readytype/actions/runs/31860207850) passed version validation, tests, official analytics configuration, build, sensitive-information scanning, packaging, and publishing.
- Public [v1.5.1](https://github.com/whnnick/readytype/releases/tag/v1.5.1) is latest, neither draft nor prerelease, and contains `ReadyType.app.zip`, `ReadyType.dmg`, and `SHA256SUMS.txt`.
- Freshly downloaded ZIP and DMG passed `SHA256SUMS.txt`; the ZIP contains `1.5.1 (96)` and passes strict signature verification, and the DMG passes `hdiutil verify`.

## Release Blockers

- None for 1.5.1. The separate 1.6.0 selected-text workflow remains under development.
