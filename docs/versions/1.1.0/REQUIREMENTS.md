# ReadyType 1.1.0 Requirements

## Background

ReadyType 1.0.0 is available for public testing. The next stage should not simply add more features. It should turn repeated real-world input issues into maintainable product capabilities: common words, confirmed learning, app-aware tone, shortcut configuration, and high-accuracy speech-package status.

Some foundation already exists in the codebase. Version 1.1.0 should productize and tighten it instead of rebuilding it from scratch.

## Existing Foundation

### Common Words

Already available:
- `UserVocabularyStore` supports local save, load, deduplication, deletion, and multi-line import.
- `SettingsViewModel` supports adding, importing, and deleting common words.
- `SmartTermDictionary`, `ContextualVocabularyProvider`, and `TermCorrectionService` already use user vocabulary for recognition context and term correction.
- Tests cover `UserVocabularyStoreTests`, `SettingsViewModelTests`, `ContextualVocabularyProviderTests`, and `TermCorrectionServiceTests`.

Current gaps:
- The Settings experience needs to be reviewed for clarity.
- The Companies / Organizations category has been added, and the default category label now uses "Other"; remaining work is to validate whether the category wording is clear for regular users.
- User-facing explanations such as possible aliases and scopes need to be understandable.

### Confirmed Learning Suggestions

Already available:
- The console can show suggestions to add common words.
- Users can ignore or remember a spelling.
- `UserVocabularySuggestionService` and `UserVocabularyLearningService` exist.
- Settings already has a learning-suggestion toggle.

Current gaps:
- Memory-related wording has been changed to common-word suggestion language; remaining work is to review whether the console and Settings copy are clear enough.
- Rejection cooldown, deduplication, length limits, and spoken-noise filtering need product validation.
- The privacy rule must be explicit: no full private text is saved.

### App-Aware Tone

Already available:
- `OutputScenario`, `OutputContext`, and `PromptTemplates` handle scenario and prompt behavior.
- The console already exposes writing scenarios.
- Some tests cover email, AI tools, technical terms, and polished writing.

Current gaps:
- Chat output can still sound too formal.
- Automatic app detection and manual scenario priority need to be explicit.
- We need testable rules for chat, email, notes, documents, and AI tools.

### Custom Shortcuts

Already available:
- `VoiceShortcutConfiguration` supports double-press `Option`, `Control`, `Command`, and `Fn`.
- `SettingsStore` persists the shortcut configuration.
- `GlobalShortcutService` triggers based on configuration.
- `Esc` cancellation has tests.

Current gaps:
- The Settings copy for trigger configuration needs review.
- Shortcut changes should apply immediately with understandable failure messages.
- `Esc` cancellation must not regress.

### High-Accuracy Speech Package Status

Already available:
- Download, deletion, prewarm, and status display exist.
- `LocalSpeechModelReadiness` merges disk state and runtime state.
- User-facing copy uses "high-accuracy speech package".

Current gaps:
- Version or manifest tracking is needed for update prompts.
- Status must reflect real state and avoid contradictory "ready" versus "not ready" messages.
- Network or update-check failures should show a temporary unable-to-check state, not a false failure.

## 1.1.0 Product Requirements

### P0: Productize Common Words

Users can maintain common words in Settings. Common words should cover names, projects, products, technical terms, companies or organizations, and other.

Acceptance:
- Add, delete, and import actions provide clear Settings feedback.
- Common words persist after app restart.
- Common words influence later recognition context and term correction.
- User-facing copy does not mention hotwords, training, or model learning.

### P0: Tighten Confirmed Learning Suggestions

ReadyType may suggest adding terms to common words, but only after user confirmation.

Acceptance:
- The suggestion area explains that confirming helps future recognition.
- Users can confirm or ignore.
- Ignored suggestions are not repeated immediately.
- Full sentences, private chats, and email body text are not saved.

### P0: App-Aware Tone

Output must match the scenario.

Acceptance:
- WeChat/chat: natural and concise; no unsupported polite endings such as "thanks" or "please".
- Email: when email intent is clear, output greeting, body paragraphs, and an appropriate ending.
- Notes: structured for capture.
- AI tools: clear task instructions, not casual chat.

### P1: Review Custom Shortcut Experience

Users can change the trigger, while double-press `Option` remains the default.

Acceptance:
- Changes apply immediately.
- The old trigger no longer starts input.
- `Esc` cancellation still works.
- Copy says "start speaking" and "finish input" rather than overusing "recording".

### P1: High-Accuracy Speech Package Update Prompts

Users can understand whether the high-accuracy speech package is installed, ready, or needs an update.

Acceptance:
- Missing, downloading, preparing, ready, check-failed, and update-available states are distinguishable.
- Ready state does not regress without real missing or damaged files.
- Users can delete and re-download.
- Update-check failures show a temporary user-facing state.

## Non-Goals

- No OpenAI, Anthropic, Gemini, or other model providers.
- No cloud speech-recognition API configuration.
- No silent learning.
- No full transcript history.
- Liquid Glass HUD is not a 1.1.0 blocker.

## Verification Requirements

- Add unit tests before code changes.
- Run focused test filters for each module.
- Run `swift test` after coherent milestones.
- Run `scripts/build-app.sh` and `scripts/package-dmg.sh` before packaging.
- Real voice retests should record scenario, raw recognition, final output, latency, and paste result.
