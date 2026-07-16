# Roadmap

ReadyType 1.3.0 establishes privacy-first anonymous product analytics. The next goal is to use real usage evidence to improve recognition quality, response time, and context awareness.

## Current Version

- Chinese-first macOS voice input.
- Double-press `Option` to start and finish, `Esc` to cancel.
- Direct dictation, polished writing, Chinese-to-English translation, and AI-ready instructions.
- DeepSeek V4 Flash as the default AI output model.
- High-accuracy speech package, automatic recognition routing, and common-word suggestions.
- Automatic paste with clipboard fallback.
- Unsigned and non-notarized DMG distribution.

## Version Plan

Version 1.2.0 is tracked in [ReadyType 1.2.0](./versions/1.2.0/README.md): refresh the UI and interaction model so the HUD becomes the primary experience, the main window becomes a management surface, and Follow System, Light, and Dark appearances are supported.

Version 1.3.0 is tracked in [ReadyType 1.3.0](./versions/1.3.0/README.md): establish anonymous product analytics that never collect user content, covering activation, retention, adoption, failures, and latency.

Version 1.4.0 is tracked in [ReadyType 1.4.0](./versions/1.4.0/README.md): add Trending Vocabulary Packs based on mature input-method patterns so recent movies, technology products, and sports terms can participate as low-priority recognition candidates.

### UI and Interaction Refresh

Automatically understand the current app and intent by default, reducing the number of output-mode, writing-scenario, and recognition choices shown together. The voice HUD provides stable, low-distraction, and explainable state feedback.

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

### Trending Vocabulary Packs

Update publicly curated recent terms in the background to improve recognition of movie names, product names, sports events, and similar proper nouns. This must be locally cached, optional, deletable, expiring, and must not upload user input.

### Voice Input HUD

Complete the HUD state refresh in 1.2.0 using native material, local edge-light motion, stable layout, Light and Dark themes, and Reduce Motion support.

## Not Prioritized

- Multiple LLM provider configuration.
- Engineer-oriented model marketplaces.
- Cloud speech-recognition API configuration.
- Large sets of advanced settings.

ReadyType will stay Chinese-first, low-configuration, and low-cost for everyday input.
