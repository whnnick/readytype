# Changelog

## Unreleased

### Added

- Added bilingual ReadyType 1.2.0 requirements and planning documents for Trending Vocabulary Packs, covering layered vocabulary, background updates, local caching, expiration, and performance boundaries.
- Added bilingual ReadyType 1.2.0 interaction flow diagrams for Trending Vocabulary Packs, covering visible Settings interaction, background updates, voice-input candidate decisions, and Settings information structure.
- Added high-accuracy speech-package update status checks covering not checked, checking, missing, up to date, update available, and temporarily unable to check states.
- Added 1.1.0 local release-gate records covering unit tests, build, zip, DMG, UI wording, TextEdit paste, Common Words UI, visual screenshots, and sensitive-information checks.
- Added a "Companies / Organizations" common-word category and changed the default category label from a generic wording to "Other".
- Added bilingual ReadyType 1.1.0 requirements documents and version indexes separating existing foundations, current gaps, acceptance criteria, and non-goals.
- Added bilingual ReadyType 1.1.0 planning documents covering common words, confirmed learning suggestions, app-aware tone, custom shortcuts, and high-accuracy speech package update prompts.
- Added a Chinese tester invite template that can be shared directly with first-time testers.
- Added a public roadmap and testing guide so testers can understand the current scope, feedback path, and upcoming work.
- Added troubleshooting documentation for unsigned launch, permissions, shortcuts, paste fallback, DeepSeek connection checks, high-accuracy speech package readiness, and feedback reporting.

### Changed

- Added manifest version metadata for the high-accuracy speech package and separated update status from readiness status in Settings.
- Tightened English email translation output so explicit recipients are preserved, requested numbered lists are kept, and subject lines are not added unless requested.
- Confirmed common-word suggestions now filter overlong candidates and spoken stop words, avoiding full sentences, private body text, and noise such as "OK", "好了", or "完成".
- Reworded common-word suggestion copy to avoid implying silent memory or training.
- Highlighted that AI output uses DeepSeek V4 Flash by default and is typically very low-cost for everyday usage under current official API pricing.

## 1.0.0 - 2026-06-24

Initial public release candidate for ReadyType.

### Added

- GitHub issue templates and README feedback links for install, permission, shortcut, paste, recognition-quality, and output-tone reports.
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
