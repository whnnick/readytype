# ReadyType 1.4.0

ReadyType 1.4.0 establishes privacy-first anonymous product analytics so future bilingual work can be guided by verified usage, performance, and reliability data.

## Documents

- [Requirements](./REQUIREMENTS.md)
- [Anonymous Event Specification](./ANALYTICS_SPEC.md)
- [Implementation Plan](./PLAN.md)

## Current Boundaries

- 1.4.0 never uploads audio, transcripts, final output, window titles, common words, clipboard content, or API keys.
- Public source builds use `NoopAnalyticsTracker` by default and send nothing.
- Only official builds with an explicitly injected analytics configuration can send events.
- Users can disable anonymous analytics from Permissions & Privacy.
- This release establishes the data foundation; English recognition and mixed Chinese-English speech remain later work.

## Current Status

The event allowlist, user control, core input funnel instrumentation, and No-op default are complete. The official provider, production configuration verification, release-facing README updates, and 1.4.0 black-box checks remain pending, so current builds do not produce remote analytics data.
