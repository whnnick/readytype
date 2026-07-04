# Roadmap

ReadyType 1.0.0 is available as a public testing build. The next goal is to make the voice-input experience more stable, more context-aware, and less intrusive.

## Current Version

- Chinese-first macOS voice input.
- Double-press `Option` to start and finish, `Esc` to cancel.
- Direct dictation, polished writing, Chinese-to-English translation, and AI-ready instructions.
- DeepSeek V4 Flash as the default AI output model.
- High-accuracy speech package, automatic recognition routing, and common-word suggestions.
- Automatic paste with clipboard fallback.
- Unsigned and non-notarized DMG distribution.

## Next Focus Areas

The 1.1.0 scope is defined in [Requirements](./versions/1.1.0/REQUIREMENTS.md), and the detailed plan is available in [ReadyType 1.1.0 Plan](./versions/1.1.0/PLAN.md).

### Common Words

Let users maintain their own words, such as names, projects, products, technical terms, and company names. The goal is to reduce recognition errors for domain-specific terms, capitalization, and mixed Chinese/English input.

### Learning Suggestions

After user confirmation, repeatedly corrected terms can be added to common words. This must stay explicit and controllable, without silently collecting private content or polluting the word list with bad corrections.

### Context-Aware Tone

Adjust output tone based on the current app and writing scenario. Chat should sound natural, email and documents should be clearer and more complete, and AI tools should receive task-like instructions.

### Custom Shortcuts

Allow users to replace the default double-press `Option` trigger with another shortcut to avoid conflicts with personal input methods or system habits.

### High-Accuracy Speech Package Updates

Provide clearer status, version, update prompts, and re-download controls so users know whether the package is ready and when it should be updated.

### Voice Input HUD

Continue refining the HUD visuals and motion, with a direction closer to macOS Liquid Glass and low-distraction system overlays.

## Not Prioritized

- Multiple LLM provider configuration.
- Engineer-oriented model marketplaces.
- Cloud speech-recognition API configuration.
- Large sets of advanced settings.

ReadyType will stay Chinese-first, low-configuration, and low-cost for everyday input.
