# ReadyType 1.3.0 Black-Box Functional Check

Last updated: July 16, 2026. The released build is `1.3.0 (87)`.

## Requirement Mapping and Status

| Product item | Status | Verification evidence |
| --- | --- | --- |
| Anonymous event allowlist | Complete | Business events map to fixed names and enumerated properties; tests cover allowed fields without accepting transcript or output text. |
| User control | Complete | `ConsentAwareAnalyticsTracker` tests prove disabled analytics drops new events; the provider receives only fixed events allowed through that control. |
| Public source sends nothing by default | Complete | Missing App ID produces `NoopAnalyticsTracker`; ordinary builds contain no analytics configuration in `Info.plist`. |
| Official provider | Complete | TelemetryDeck Swift SDK 2.14.1 is integrated with automatic session events and session statistics disabled. |
| Privacy disclosure | Complete | Permissions & Privacy and both READMEs describe allowed metadata and prohibited data. |
| Test Mode isolation | Complete | Internal builds can inject Test Mode so acceptance events stay out of production data. |
| Official service connectivity | Complete | TelemetryDeck accepted an isolated `app_launched` event using the official App ID with `HTTP 200 OK`. |
| Dashboard event visibility | Complete | On July 16, Test Mode Recent Events showed `app_launched`; the dashboard reported one test user, one event, zero errors, and SwiftSDK 2.14.1. |
| Server-side field audit | Complete | The `app_launched` detail contained 75 fields. ReadyType supplied only the allowlisted `type`, `version`, `build`, `os_major`, and `architecture`; the remainder was fixed TelemetryDeck compatibility metadata. A field-name scan found no audio, transcript, output, window-title, common-word, clipboard, DeepSeek, or API-key field. |

## Verification Performed

- `ReadyTypeAnalyticsTests`: 6 executed, 0 failures.
- Configured build: App ID and Test Mode were injected; strict app-bundle signature structure verification passed.
- A TelemetryDeck organization and ReadyType macOS app were created on the free plan.
- The official ingestion endpoint returned `HTTP 200 OK`; the test payload contained only the allowlisted version, build, macOS major version, and architecture fields.
- Build 86 was rebuilt with the official App ID and Test Mode and launched again. The local `telemetrysignalcache` was empty afterward, so the event was not left queued by a network failure.
- On July 16, TelemetryDeck Test Mode Recent Events confirmed that `app_launched` was ingested for `1.2.0 (86)` with SDK 2.14.1.
- Dashboard event-detail audit: 75 field names, zero prohibited-content matches, and ReadyType custom fields matching the anonymous event specification.
- After No-op acceptance, an ordinary build was restored to confirm that source builds without injected configuration contain neither the App ID nor Test Mode.
- The official release-candidate build contains the official App ID and explicitly does not contain Test Mode; its version is `1.3.0 (87)`.
- `swift test`: 371 executed, 11 skipped by environment, 0 failures; the 2,000-term vocabulary stress-test P95 was 8.272 ms.
- Strict app-bundle signature structure, ZIP, DMG, and `hdiutil verify`: passed; the ZIP contains `1.3.0 (87)`.
- `python3 scripts/check-sensitive-info.py`: passed.
- Added reusable `scripts/verify-release-local.sh` and `scripts/verify-ui.sh` gates for future releases.
- `scripts/verify-ui.sh`: passed; all eight main pages opened with their core copy visible.
- `scripts/verify-release-local.sh`: passed end to end.
- GitHub CI run 51 and Release run 2: passed.
- The public `v1.3.0` Release is latest, non-draft, and non-prerelease; `ReadyType.app.zip`, `ReadyType.dmg`, and `SHA256SUMS.txt` are present.
- Downloaded release assets passed SHA-256 verification; the DMG checksum is valid, and the ZIP contains `1.3.0 (87)` with the official analytics App ID, no Test Mode, and a valid code-signature structure.
- `git diff --check`: passed.

## Real-Environment Acceptance Pending

1. After the first real post-release data batch, sample the enumerated-property distribution for `voice_input_started` and `voice_input_finished`.

## Release Blockers

- None. `v1.3.0` is published and the remote release state and downloadable assets have been verified.
