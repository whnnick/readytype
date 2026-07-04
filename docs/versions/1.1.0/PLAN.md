# ReadyType 1.1.0 Plan

ReadyType 1.1.0 focuses on real-world input quality: better common-word recognition, more natural app-aware tone, clearer shortcut configuration, and clearer high-accuracy speech-package status.

See [Requirements](./REQUIREMENTS.md) for scope boundaries. The current code already has foundations for common words, confirmed suggestions, shortcut configuration, and high-accuracy speech-package status. This plan focuses on productizing and tightening those capabilities, not rebuilding them from scratch.

## Goals

- Let users maintain common words for names, projects, products, technical terms, and companies.
- Provide learning suggestions only after user confirmation; no silent learning.
- Adjust output tone based on app and writing scenario, especially to make chat output less overly formal.
- Support custom trigger shortcuts while keeping double-press `Option` as the default.
- Make the high-accuracy speech package status, version, and update path clearer.
- Keep the current DeepSeek-only, Chinese-first, low-configuration, low-cost direction.

## Non-Goals

- No additional LLM providers.
- No cloud speech-recognition API configuration.
- No engineer-oriented model marketplace.
- No silent collection of private text for learning.
- Liquid Glass HUD refinement is not a 1.1.0 release blocker.

## Scope

### 1. Common Words

User value: users can add names, project names, product names, technical terms, and company names.

Requirements:
- Add a Common Words section in Settings.
- Support add, delete, and view.
- Use simple categories: names, projects, products, technical terms, companies, and other.
- Use user-facing wording such as "common words", not "hotwords", "dictionary", or "training".

Implementation:
- Reuse `UserVocabularyStore`, `ContextualVocabularyProvider`, and `SmartTermDictionary`.
- Store data locally under Application Support.
- Make common words available to recognition and post-processing without noticeably increasing latency.

Acceptance:
- Added words appear immediately in Settings.
- Added words persist after app restart.
- Deleted words disappear from Settings.

### 2. Confirmed Learning Suggestions

User value: ReadyType can suggest adding repeatedly corrected terms, but only after the user confirms.

Requirements:
- Use wording such as "suggest adding to common words".
- Do not save full sentences.
- Do not save private chats or email body text as learning data.

Implementation:
- Reuse `UserVocabularyLearningService` and `UserVocabularySuggestionService`.
- Save only candidate terms, confirmation state, category, and timestamp.
- Add deduplication, length limits, and spoken-noise filtering.

Acceptance:
- Repeated candidate terms appear as suggestions.
- Rejected suggestions are not immediately suggested again.
- Confirmed suggestions become common words.

### 3. App-Aware Tone

User value: output should match chat, email, notes, documents, and AI tools.

Requirements:
- Chat should sound natural and avoid unsupported polite endings.
- Email should preserve greeting, paragraphing, and sign-off structure when intent is clear.
- Notes should be structured for capture.
- AI tools should receive clear task instructions.

Implementation:
- Reuse `OutputScenario`, `OutputContext`, and `PromptTemplates`.
- Infer scenario from frontmost app bundle id, window title, and manual scenario selection.
- Manual scenario selection overrides inference.

Acceptance:
- Chat output does not add unsupported "thanks" or overly formal endings.
- Email intent produces email format.
- AI-tool scenarios produce task instructions instead of casual chat text.

### 4. Custom Shortcuts

User value: users can avoid conflicts with input methods, system habits, or app shortcuts.

Requirements:
- Default remains double-press `Option`.
- Settings provides clear trigger configuration.
- Changes apply immediately with understandable error messages.

Implementation:
- Reuse `VoiceShortcutConfiguration` and `GlobalShortcutService`.
- Store configuration in `AppSettings`.
- Keep `Esc` cancellation.

Acceptance:
- Default double-press `Option` works.
- After changing the trigger, the new trigger works and the old one no longer triggers.
- `Esc` still cancels active voice input.

### 5. High-Accuracy Speech Package Updates

User value: users know whether the high-accuracy speech package is installed, ready, or needs an update.

Requirements:
- Use "high-accuracy speech package" consistently.
- Status must reflect real state and must not be hard-coded.
- Provide delete, re-download, and version information.

Implementation:
- Extend `LocalSpeechModelManager`, `LocalSpeechModelReadiness`, and `LocalSpeechModelDownloadService`.
- Track local package version or manifest version.
- If update checking fails, show "unable to check right now" instead of a false failure.

Acceptance:
- Missing, downloading, preparing, ready, and check-failed states are distinguishable.
- Ready state does not regress unless files are missing or damaged.
- Deleting the package immediately changes state to missing.

## Development Order

1. Common Words UI and local storage.
2. Confirmed learning suggestions.
3. App-aware tone.
4. Custom shortcuts.
5. High-accuracy speech package update prompts.
6. Real-app regression testing and documentation updates.

## Test Plan

- `swift test`
- `scripts/build-app.sh`
- `scripts/package-dmg.sh`
- Manual testing in WeChat, Notes, browsers, email/document tools, and AI tools.
- For real voice tests, record scenario, raw recognition, final output, latency, and paste result.

## Release Criteria

- No known blocking issues in `Esc` cancellation, trigger handling, or automatic paste.
- Common words and learning suggestions do not store full private text.
- High-accuracy speech package status matches real state.
- README, Roadmap, Testing Guide, Troubleshooting, and changelog are updated.
- Release artifact includes a DMG and passes sensitive-information checks.
