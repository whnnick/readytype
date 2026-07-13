# ReadyType 1.4.0 Implementation Plan: Anonymous Product Analytics

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
6. Update bilingual README, changelog, testing guidance, and the 1.4.0 black-box check.

## Verification

- `swift test`
- `scripts/build-app.sh`
- Search event properties for free-form text, API keys, window titles, transcripts, and output
- Use a test tracker to prove disabled analytics records nothing
- Prove builds without official configuration send no analytics network requests

## Release Gate

The event specification, privacy copy, implementation, and tests must agree. A build with anonymous analytics enabled ships only after its official configuration is verified.

