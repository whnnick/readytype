# ReadyType 1.3.0 Black-Box Functional Check

Last updated: July 14, 2026. The current acceptance build is still labeled `1.2.0 (80)` and has not entered the 1.3.0 release stage.

## Requirement Mapping and Status

| Product item | Status | Verification evidence |
| --- | --- | --- |
| Anonymous event allowlist | Complete | Business events map to fixed names and enumerated properties; tests cover allowed fields without accepting transcript or output text. |
| User control | Automated pass, remote check pending | `ConsentAwareAnalyticsTracker` tests prove disabled analytics drops new events; remote event-count confirmation waits for initial dashboard ingestion. |
| Public source sends nothing by default | Complete | Missing App ID produces `NoopAnalyticsTracker`; ordinary builds contain no analytics configuration in `Info.plist`. |
| Official provider | Complete | TelemetryDeck Swift SDK 2.14.1 is integrated with automatic session events and session statistics disabled. |
| Privacy disclosure | Complete | Permissions & Privacy and both READMEs describe allowed metadata and prohibited data. |
| Test Mode isolation | Complete | Internal builds can inject Test Mode so acceptance events stay out of production data. |
| Official service connectivity | Complete | TelemetryDeck accepted an isolated `app_launched` event using the official App ID with `HTTP 200 OK`. |
| Dashboard event visibility | Partial | Test Mode is enabled; the free plan ingests once per day and Recent Events has not displayed the initial event yet. |

## Verification Performed

- `ReadyTypeAnalyticsTests`: 6 executed, 0 failures.
- Configured build: App ID and Test Mode were injected; strict app-bundle signature structure verification passed.
- A TelemetryDeck organization and ReadyType macOS app were created on the free plan.
- The official ingestion endpoint returned `HTTP 200 OK`; the test payload contained only the allowlisted version, build, macOS major version, and architecture fields.
- `git diff --check`: passed.

## Real-Environment Acceptance Pending

1. After the free plan's next ingestion, confirm `app_launched` in Test Mode Recent Events.
2. Complete one real voice input and confirm only allowlisted properties on `voice_input_started` and `voice_input_finished`.
3. Disable Help Improve ReadyType, then relaunch and use voice input; confirm no new events appear.
4. Confirm event details contain no audio, transcript, final output, window title, common words, clipboard content, or DeepSeek key.

## Release Blockers

- Complete initial dashboard ingestion and the remote opt-out check.
- Update the release version and build number to the selected 1.3.0 values.
- Confirm the public release build injects the App ID without Test Mode.
- Run the full test, app/ZIP/DMG packaging, sensitive-data scan, and GitHub Release verification flow.
