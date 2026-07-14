# ReadyType 1.3.0 Implementation Plan: Anonymous Product Analytics

## Architecture

```text
Business modules
  -> ReadyTypeAnalyticsEvent (closed enum)
  -> AnalyticsTracking
       -> NoopAnalyticsTracker (default)
       -> Official provider adapter (explicit configuration)
```

## Implementation Order

1. Add event models, bucket helpers, `AnalyticsTracking`, and the no-op implementation.
2. Persist the setting and add a Help Improve ReadyType toggle.
3. Explain collected and prohibited data in Permissions & Privacy.
4. Instrument launch, activation, voice input, speech package, delivery, and fixed-error events.
5. Add the official provider adapter; missing or invalid configuration must fall back to no-op.
6. Update bilingual README, changelog, testing guidance, and the 1.3.0 black-box check.

## Verification

- `swift test`
- `scripts/build-app.sh`
- Search event properties for free-form text, API keys, window titles, transcripts, and output
- Use a test tracker to prove disabled analytics records nothing
- Prove builds without official configuration send no analytics network requests

## Release Gate

The event specification, privacy copy, implementation, and tests must agree. A build with anonymous analytics enabled ships only after its official configuration is verified.

The official provider uses TelemetryDeck Swift SDK 2.14.1. `READYTYPE_TELEMETRYDECK_APP_ID` injects the App ID into the app bundle's `Info.plist` at build time. The App ID routes data and is not a dashboard credential, but it remains outside the repository so ordinary source builds stay no-op. Management tokens and dashboard credentials must never enter client builds.

The GitHub Release workflow reads the App ID from the matching Actions repository variable. A missing or malformed variable must stop the release so an official installer cannot be published without analytics enabled. Release builds must not enable Test Mode.

Internal acceptance builds may additionally set `READYTYPE_TELEMETRYDECK_TEST_MODE=1` so events appear only in TelemetryDeck Test Mode. This flag is not used for public release builds and cannot be enabled without an App ID.
