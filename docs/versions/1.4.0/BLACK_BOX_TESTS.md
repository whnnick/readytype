# ReadyType 1.4.0 Black-box Acceptance

Last updated: 2026-07-18. The current release is `1.4.0 (88)`.

## Requirement Coverage

| Product item | Status | Evidence |
| --- | --- | --- |
| Public-source trending pack | Complete | The maintenance pipeline reads Wikimedia Pageviews and Wikidata. The live `2026.07.16` pack contains 174 traceable terms. |
| Production signing and verification | Complete | The Ed25519 private key exists only in the maintainer Keychain and GitHub Secret. The app embeds the public key, and its verifier accepted the live manifest, hash, and signature. |
| Silent background updates | Complete | The app checks after eight idle seconds and every 24 hours thereafter. Recording reads only an in-memory snapshot. |
| Local cache and failure fallback | Complete | Automated coverage includes atomic version directories, active pointers, previous-valid fallback, missing-local recovery after 304, expiration, and offline behavior. |
| Layered vocabulary priority | Complete | User, built-in, and contextual terms outrank trending terms. At most 20 trending terms participate per request, and aliases do not trigger aggressive rewriting. |
| User interface | Complete | Speech Recognition shows plain-language status, source/privacy information, and Update now. The real app transitioned correctly through updating and updated states. |
| Real-voice trending names | Complete | The Chinese names for “Moana live action” and “Christopher Nolan” were both emitted correctly. |
| Ordinary-expression false-positive control | Complete | The Chinese phrase using “effort” followed by “women's football” remained two separate meanings and was not merged into a trending title. |
| Mixed-language technical terms | Partial | One long sentence degraded Redis and GitHub Actions into English near-homophones; a shorter retest emitted both terms correctly. This is existing mixed-language ASR variance, and trending terms did not pollute technical content. |

## Verification Performed

- Live pack: `packVersion=2026.07.16`, `minimumAppVersion=1.4.0`, 174 terms, production signature accepted.
- Real-network acceptance downloaded, verified, installed into a temporary store, and loaded through the coordinator.
- Final release-gate `swift test`: 398 executed, 13 conditionally skipped for real environments, 0 failures.
- Final contextual-vocabulary performance: P95 18.060 ms; timeout benchmark 83.667 ms.
- `scripts/build-app.sh`: passed and produced `1.4.0 (88)`.
- Strict app-bundle signature structure and sensitive-information scans: passed.
- GitHub CI [29628788739](https://github.com/whnnick/readytype/actions/runs/29628788739): tests, build, sensitive scan, ZIP, DMG, and artifact uploads all passed.
- Real-app manual update transitioned from updating back to automatically updated and persisted the live pack in the user cache.
- `scripts/verify-release-local.sh`: fully passed, including official analytics configuration, UI, ZIP, DMG, and `hdiutil verify`.
- GitHub Release run [29630374845](https://github.com/whnnick/readytype/actions/runs/29630374845): tests, official build, sensitive scan, packaging, and publishing all passed.
- The public [v1.4.0 Release](https://github.com/whnnick/readytype/releases/tag/v1.4.0) is latest, neither draft nor prerelease, and contains all three expected assets.
- Freshly downloaded ZIP and DMG files passed `SHA256SUMS.txt`; the ZIP contains `1.4.0 (88)` with official analytics configuration, Test Mode disabled, valid signature structure, and a valid DMG checksum.

## Real-environment Follow-up

1. Observe mixed Chinese/English behavior across accents and devices after release; do not attribute a single failure to user pronunciation.
2. Evaluate trending-term hit and false-positive rates with early users without uploading audio, transcripts, or final output.

## Release Blockers

- None. `v1.4.0` is public, and both remote state and downloaded artifacts have been verified.
