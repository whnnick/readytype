# ReadyType 1.1.0

ReadyType 1.1.0 focuses on productizing real-world input quality: common words, confirmed learning suggestions, app-aware tone, custom shortcuts, and high-accuracy speech-package status.

## Documents

- [Requirements](./REQUIREMENTS.md)
- [Implementation Plan](./PLAN.md)

## Current Assessment

ReadyType 1.0.0 already includes part of the foundation: common-word storage, import, confirmed suggestions, shortcut configuration, and high-accuracy speech-package status display. Version 1.1.0 should not rebuild these foundations. It should make them clearer, more stable, and easier for regular users to understand.

Baseline checks:
- `swift test --filter UserVocabularyStoreTests`: 9 tests passed.
- `swift test --filter SettingsViewModelTests`: 18 tests passed.

## Development Order

1. Productize Common Words.
2. Tighten confirmed learning suggestions.
3. Improve app-aware tone.
4. Review custom shortcut experience.
5. Improve high-accuracy speech-package status and update prompts.
6. Update docs, tests, and release preparation.
