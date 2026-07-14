# ReadyType 1.3.0 Requirements: Anonymous Product Analytics

## Background

The current Usage Overview stores only daily completed-input counts, recording duration, and output characters on the user's Mac. The project cannot measure activation, retention, feature adoption, failures, or latency, and therefore cannot evaluate an English release with real evidence.

## Product Goals

- Measure installation, first successful input, activity, and retention without collecting user content.
- Understand recognition routes, output methods, scenario categories, and high-accuracy package adoption.
- Report fixed error codes and bucketed latency to detect regressions.
- Explain the scope clearly and let users disable anonymous analytics at any time.
- Keep the existing local Dashboard and never upload its history to GitHub or an analytics provider.

## Privacy Requirements

Audio, raw transcripts, final output, window titles, file paths, clipboard content, common words, DeepSeek requests or responses, API keys, contacts, and account details must never be uploaded. The app may send only events and enumerated properties listed in `ANALYTICS_SPEC.md` plus audited compatibility metadata supplied by the TelemetryDeck SDK.

## Acceptance Criteria

- With no provider configuration, the app sends no analytics network traffic and voice input is unaffected.
- Disabling anonymous analytics immediately stops new events.
- Event properties cannot contain free-form text.
- Failures send fixed error codes, never `localizedDescription`.
- Analytics failures never block launch, recording, recognition, processing, or paste.
- Unit tests cover persistence, the event allowlist, disabled behavior, and no-op behavior.

## Non-goals

- No screen recording, session replay, user profiling, advertising attribution, or cross-site tracking.
- Do not upload the existing `UsageStatistics.json` file.
- Do not store admin tokens or dashboard credentials in the client.
- English UI, English ASR, and mixed Chinese-English speech are outside this release.
