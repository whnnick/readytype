# ReadyType 1.2.0

ReadyType 1.2.0 focuses on a UI and interaction refresh: moving from a mode-heavy control panel toward a quiet system-level voice-input experience with clear feedback only when needed.

## Documents

- [Requirements](./REQUIREMENTS.md)
- [Interaction Architecture](./INTERACTION_ARCHITECTURE.md)
- [Visual and Motion System](./VISUAL_SYSTEM.md)
- [Implementation Plan](./PLAN.md)
- [Black-Box Functional Check](./BLACK_BOX_TESTS.md)

## Direction

- The voice HUD is the primary experience; the main window becomes a management surface.
- App, tone, and writing context are automatic by default.
- Follow System, Light, and Dark appearances are supported.
- Borrow Typeless-style low-distraction principles without copying its brand assets or interface.
- Preserve the recording, recognition, DeepSeek, paste, vocabulary, and permission pipelines.

## Release Boundary

This release does not also add Trending Vocabulary Packs, a new recognition engine, multiple AI providers, or complete transcription history. Trending Vocabulary Packs move to [1.4.0](../1.4.0/README.md).
