# Changelog

## Unreleased

- Added bilingual ReadyType 1.4.0 requirements, anonymous event specification, and implementation plan, defining that public source builds send nothing by default and that audio, text content, window titles, common words, clipboard content, and API keys are prohibited.
- Added a strongly typed anonymous event layer, user control, and No-op default covering launch, input start, completion, cancellation, and fixed error codes; current public builds still send no network analytics.
- Precomputed contextual-vocabulary ranking context and sort keys so the 2,000-term stress-test P95 remains reliably below the 50 ms gate.
- Integrated the official TelemetryDeck Swift SDK as an optional analytics provider; its App ID is injected only at build time, missing configuration remains no-op, and automatic session events and session statistics are disabled.
- The build script now copies and verifies TelemetryDeck's privacy-manifest bundle so custom `.app` packaging cannot omit the third-party privacy declaration.

## 1.2.0 - 2026-07-13

- Applied Common Words to both fast and high-accuracy Whisper recognition and supplied a bounded, deduplicated canonical-spelling list to AI cleanup.
- Re-adding the same Common Word can now update its canonical capitalization without replacing its category, aliases, or learning metadata.
- Fixed contextual-vocabulary work continuing after its timeout was cancelled, preventing delayed fallback and environment-sensitive CI failures.
- Added tag-triggered GitHub Releases with version validation, tests, sensitive-information scanning, ZIP and DMG packages, and SHA-256 checksums.
- Normalized Chinese and mixed Chinese-English output to full-width Chinese punctuation while keeping fully English output in ASCII punctuation; versions, URLs, times, and numeric formats remain intact.
- Strengthened cleanup output requirements to restore sentence-internal and sentence-ending punctuation.

### Added

- Common Words entries containing spaces can be split into independent terms after explicit confirmation, making accidental combined entries easy to correct.
- Added a local usage dashboard with aggregate voice time, completed inputs, output characters, estimated time saved, and a 14-day trend; transcript text is never stored.
- Added a Chinese Text setting with Simplified Chinese, Traditional Chinese, and Follow System options; Simplified Chinese is the default and applies consistently to direct and AI-assisted output.
- Added bilingual ReadyType 1.2.0 UI/UX Refresh requirements, interaction architecture, visual and motion guidance, and implementation plans.
- Added persisted Follow System, Light, and Dark appearances shared by the main window, HUD, and menu bar popover.

### Changed

- Common Words now states that spaces belong to a term and that multiple terms require newlines, commas, enumeration commas, or semicolons, preserving multi-word product names.
- Reduced the voice-input capsule to a compact fixed size, tightened its status light, timer, and waveform, and removed the redundant scenario badge while preserving essential state and output mode feedback.
- Reordered the sidebar so Home appears first and Usage Overview follows it, matching the default page with the navigation hierarchy.
- Fixed the menu bar popover being difficult to dismiss and added Escape-to-close behavior.
- Usage Dashboard can clear local statistics, and streaks remain valid through the current day before the user records new activity.
- Unified the AppKit popover and SwiftUI content dimensions to avoid relayout jank, and applied appearance selection to the entire menu bar popover.
- Home now uses a green status dot when high-accuracy recognition is enabled and ready, while recording, processing, and error states keep priority.
- Advanced the current development build to `1.2.0 (70)` so test artifacts no longer reuse stale build numbers.
- Enabled VAD chunking for high-accuracy recognition and reject anomalous transcripts made from repeated long segments before they can be pasted.
- Moved Trending Vocabulary Packs and its UI prototype from 1.2.0 to 1.3.0 so recognition-candidate architecture does not change in the same release as the UI refresh.
- Reorganized the main window into Home, Common Words, Language & Output, Shortcuts, Speech Recognition, Permissions & Privacy, and About, with settings scoped to each destination.
- Replaced mode and scenario controls on Home with a quiet summary of runtime status, shortcut, speech package, default output, and recent results.
- Refined the HUD into a fixed-size adaptive glass capsule with a localized top-edge light sweep and reduced-motion fallback.
- Improved the Home and About product explanations, removed the placeholder English sidebar subtitle, and increased Light sidebar and selection contrast.
- Hid model version dates from user-facing speech-package update status while retaining internal version comparison and safe update behavior.
- Clarified the no-update speech-package status so users are told that the latest package is installed and no action is needed.
- Rewrote Common Words guidance with a concrete misrecognition example, clearer reminder and save boundaries, and user-facing bulk-add wording.
- Common Words bulk add now accepts newlines, Chinese/English commas, enumeration commas, and semicolons, deduplicates and stores each term independently, and migrates previously combined comma entries.
- Common Words manual add does not ask users to configure a scope; ReadyType adjusts usage priority automatically from the current app, category, and context.
- Reorganized Language & Output around Default Output, AI Features, and delivery to the current app, with DeepSeek service and model fields moved into Advanced Connection Settings.
- Fixed Follow System updating only the title bar in some transitions, unified AppKit and SwiftUI appearance resolution, added layered off-white surfaces, animated theme changes, and aligned sidebar labels with a fixed icon column.

## 1.1.0 - 2026-07-11

### Added

- Added bilingual ReadyType 1.3.0 requirements and planning documents for Trending Vocabulary Packs, covering layered vocabulary, background updates, local caching, expiration, and performance boundaries.
- Added bilingual ReadyType 1.3.0 interaction flow diagrams for Trending Vocabulary Packs, covering visible Settings interaction, background updates, voice-input candidate decisions, and Settings information structure.
- Added a ReadyType 1.3.0 Trending Vocabulary Packs HTML UI prototype as a reference for the future SwiftUI Settings implementation.
- Added live high-accuracy speech-package update checks backed by a controlled manifest in the public ReadyType repository, covering not checked, checking, missing, current recommended version, update available, and temporarily unable to check states.
- Added a safe speech-package update flow that installs only manifest-selected official WhisperKit variants, persists the installed version, removes the previous package after success, and retains the working package on failure.
- Added 1.1.0 local release-gate records covering unit tests, build, zip, DMG, UI wording, TextEdit paste, Common Words UI, visual screenshots, and sensitive-information checks.
- Added a "Companies / Organizations" common-word category and changed the default category label from a generic wording to "Other".
- Added bilingual ReadyType 1.1.0 requirements documents and version indexes separating existing foundations, current gaps, acceptance criteria, and non-goals.
- Added bilingual ReadyType 1.1.0 planning documents covering common words, confirmed learning suggestions, app-aware tone, custom shortcuts, and high-accuracy speech package update prompts.
- Added a Chinese tester invite template that can be shared directly with first-time testers.
- Added a public roadmap and testing guide so testers can understand the current scope, feedback path, and upcoming work.
- Added troubleshooting documentation for unsigned launch, permissions, shortcuts, paste fallback, DeepSeek connection checks, high-accuracy speech package readiness, and feedback reporting.

### Changed

- Isolated the Common Words UI acceptance gate from user vocabulary data and removed its timing-sensitive notification injection.
- Non-email cleanup and English translation no longer add unsupported greetings, thanks, acknowledgements, sign-offs, or closings; email keeps its appropriate polite-closing behavior.
- Updated the 1.3.0 Trending Vocabulary Packs UI prototype toward a Typeless-inspired light glass style with a light/dark theme toggle.
- Filtered internal Common Words UI acceptance-test data so diagnostic terms cannot remain visible in real user vocabulary lists.
- Changed the speech-package status to "current recommended version", shown only when the remote manifest matches the installed version.
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
