# ReadyType 1.3.0

ReadyType 1.3.0 establishes privacy-first anonymous product analytics so future bilingual work can be guided by verified usage, performance, and reliability data.

## Documents

- [Requirements](./REQUIREMENTS.md)
- [Anonymous Event Specification](./ANALYTICS_SPEC.md)
- [Implementation Plan](./PLAN.md)
- [Black-Box Functional Check](./BLACK_BOX_TESTS.md)

## Current Boundaries

- 1.3.0 never uploads audio, transcripts, final output, window titles, common words, clipboard content, or API keys.
- Public source builds use `NoopAnalyticsTracker` by default and send nothing.
- Only official builds with an explicitly injected analytics configuration can send events.
- Users can disable anonymous analytics from Permissions & Privacy.
- This release establishes the data foundation; English recognition and mixed Chinese-English speech remain later work.

## Current Status

The event allowlist, user control, core input funnel instrumentation, TelemetryDeck provider, No-op default, and official ingestion connectivity check are complete. The free plan ingests dashboard data once per day, so initial event visibility and the remote opt-out check remain pending; source builds without injected configuration continue to send nothing.
