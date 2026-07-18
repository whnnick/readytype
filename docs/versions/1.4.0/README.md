# ReadyType 1.4.0

ReadyType 1.4.0 is scoped around Trending Vocabulary Packs: using the layered vocabulary and cloud-candidate patterns common in mature input methods to improve recognition and cleanup quality for recent movie names, technology products, sports events, and other high-frequency terms without interrupting users.

## Documents

- [Requirements](./REQUIREMENTS.md)
- [Implementation Plan](./PLAN.md)
- [Pack Generation and AI Curation](./VOCABULARY_PIPELINE.md)
- [Interaction Flow](./INTERACTION_FLOW.md)
- [Black-box Acceptance](./BLACK_BOX_TESTS.md)
- [UI Prototype](./ui/hot-vocabulary-packs.html): follows the current ReadyType sidebar and Speech Recognition page, with light/dark switching and status previews.

## Current Assessment

This should not be implemented as live hot-list scraping or by pushing a large trending list directly into the recognizer. The safer direction is:

- Keep built-in terms and user common words at the highest priority.
- Treat trending vocabulary as low-priority supplemental candidates.
- Update in the background without blocking voice input.
- Store source, category, weight, and expiration metadata for every term.
- Keep the experience silent by default while exposing only status, source information, and manual refresh in Settings.
- Add no new sidebar destination; expose one compact management section inside Speech Recognition.
- Fix the first-release sources to Wikimedia Pageviews and Wikidata; do not use commercial data APIs with unclear redistribution boundaries.
- Use AI only for offline pre-release curation; it cannot generate terms during user input or directly decide published entries.

## Release Boundary

Version 1.4.0 implements public trending-pack architecture and the first stable packs. It does not promise real-time whole-web trends, upload user input, add complex cloud services, or expose multiple third-party API configurations. Personal correction memory and confirm-first learning remain a 1.5.0 candidate and do not block this release.
