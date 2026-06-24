# Changelog

## 1.0.0 - 2026-06-24

Initial public release candidate for ReadyType.

### Added

- Chinese-first macOS voice input with double-press `Option` to start and finish.
- `Esc` cancellation during active voice input.
- Direct dictation, polished writing, Chinese-to-English translation, and AI-instruction output methods.
- DeepSeek-powered text processing with the key stored in macOS Keychain.
- Automatic recognition routing between fast system recognition and higher-accuracy local recognition when available.
- High-accuracy speech-package download, preparation, status, and deletion controls.
- Common words and confirmed personalization suggestions for terminology-heavy input.
- Menu bar popover, main console, settings, permissions, onboarding, and low-distraction voice-input HUD.
- Automatic paste with clipboard fallback.
- macOS app packaging scripts for `.app`, `.zip`, and `.dmg` artifacts.

### Notes

- The distributed 1.0.0 build is unsigned and not notarized.
- Speech recognition does not require a separate cloud speech API key.
- AI output methods call DeepSeek with the current text.
