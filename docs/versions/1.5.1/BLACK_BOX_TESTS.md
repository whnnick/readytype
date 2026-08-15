# ReadyType 1.5.1 Black-box Acceptance

## Current Status

Release verification is in progress. This patch contains recognition and output-pipeline improvements only; selected-text voice actions remain unavailable.

| Requirement | Status | Evidence |
| --- | --- | --- |
| Long-form recognition concurrency | Complete | Regression coverage verifies the eight-second boundary, concurrent start, three-second budget, and reuse of completed fast results. |
| Bounded quality selection | Complete | Engine-specific quality metadata and complete-candidate selection are covered without cross-engine raw-score comparison. |
| Contextual vocabulary and AI latency | Complete | Tests cover bounded canonical terms, general spelling rules, disabled thinking, bounded output, and split latency reporting. |
| Automated and packaging gates | Pending | Final release workflow and remote artifact verification must complete before this document can record the release as public. |

## Verified Candidate

- App: `dist/ReadyType.app`
- Version: `1.5.1 (96)`

## Release Verification

- Target release: [v1.5.1](https://github.com/whnnick/readytype/releases/tag/v1.5.1)
- Required assets: `ReadyType.app.zip`, `ReadyType.dmg`, and `SHA256SUMS.txt`
