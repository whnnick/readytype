# ReadyType 1.2.0

ReadyType 1.2.0 candidate direction is Trending Vocabulary Packs: using the layered vocabulary and cloud-candidate patterns common in mature input methods to improve recognition and cleanup quality for recent movie names, technology products, sports events, and other high-frequency terms without interrupting users.

## Documents

- [Requirements](./REQUIREMENTS.md)
- [Implementation Plan](./PLAN.md)
- [Interaction Flow](./INTERACTION_FLOW.md)

## Current Assessment

This should not be implemented as live hot-list scraping or by pushing a large trending list directly into the recognizer. The safer direction is:

- Keep built-in terms and user common words at the highest priority.
- Treat trending vocabulary as low-priority supplemental candidates.
- Update in the background without blocking voice input.
- Store source, category, weight, and expiration metadata for every term.
- Make the experience silent by default while still allowing users to disable, delete, and inspect update time in Settings.

## Release Boundary

Version 1.2.0 should implement the vocabulary-pack architecture and the first stable packs. It should not promise real-time whole-web trending terms, upload user input, add complex cloud services, or expose multiple third-party API configurations.
