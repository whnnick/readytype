# ReadyType 1.2.0 Requirements: UI/UX Refresh

## Background

ReadyType 1.1.0 has the core voice-input pipeline, but the main window exposes output mode, writing scenario, recognition mode, and speech-package state at the same level. Version 1.2.0 reduces decisions and technical language so the product feels like a simple trigger-speak-output workflow.

## Product Goals

1. Show perceptible feedback within 100 ms of the shortcut trigger.
2. Require no output-mode or writing-scenario selection by default.
3. Adapt output to chat, email, document, and AI-tool contexts.
4. Keep every state understandable: Listening, Recognizing, Polishing, Outputting, Complete, Cancelled, and Error.
5. Maintain readable contrast in Light, Dark, and Follow System appearances.
6. Respect Reduce Motion by replacing movement, sweep, and shake with fades.

## Information Architecture

The main navigation becomes Home, Common Words, Language and Output, Shortcuts, Speech Recognition, Permissions and Privacy, and About. Home only shows readiness, the active shortcut, high-accuracy recognition status, the latest result, and required user actions.

## Common Words Module

### User Goal

Users can teach ReadyType the correct spelling of names, brands, products, projects, and specialist terms that are often misrecognized. Common Words is not a transcript history and does not silently learn from edits.

### Data Unit

- One canonical spelling is one independent record, such as `ChatGPT`, `Codex`, or `GitHub Actions`.
- Spaces inside a term are content and are never separators.
- Each record contains a canonical spelling, category, applicable scopes, and optional known misrecognitions.
- Deduplication ignores case and surrounding whitespace but does not merge different complete terms.

### Add Flows

- Add One accepts exactly one complete term. Input containing separators is rejected with guidance to use bulk add.
- Add Multiple accepts newlines, Chinese/English commas, enumeration commas, and Chinese/English semicolons; it splits, deduplicates, and stores each term independently.
- Previously stored comma-combined records are migrated, deduplicated, and persisted on load so each resulting term can be deleted independently.

### Recognition Behavior

- User-saved terms rank above built-in terms and are selected according to the current app and writing context.
- Canonical spellings feed recognition context; known misrecognitions only support constrained correction and are never unconditional replacements.
- The suggestion toggle only controls post-input prompts. Nothing is saved until the user confirms it.
- Deleting a term removes it from subsequent recognition candidates immediately.

## Automation and Control

- App and semantic context determine the default output automatically.
- Direct Dictation, Translate to English, and Ask AI remain explicit secondary actions.
- HUD context labels such as “WeChat · Natural chat” make automation explainable.
- Uncertain cases fall back to generic cleanup without inventing facts, recipients, tone, or formatting.
- Advanced defaults remain available under Language and Output.

## HUD Contract

The HUD keeps stable dimensions across Ready, Listening, Recognizing, Polishing, Outputting, Complete, Copied, Cancelled, and Error states. Voice-reactive waveform motion is limited to active listening. Success feedback lasts about 900 ms; copied fallback lasts about 1.5 seconds.

## Appearance

- Follow System is the default, with explicit Light and Dark choices.
- Use native material, edge highlights, and restrained color.
- Do not use large gradient backgrounds or a continuously rotating border.
- Keep the main window dense and native to macOS rather than marketing-like.

## Non-Goals

- No pixel-level Typeless clone.
- No changes to ASR routing, DeepSeek protocol, paste strategy, or permissions.
- No full transcript history, account system, or cloud sync.
- No 1.3.0 Trending Vocabulary Packs implementation.

## Acceptance Criteria

- First-time users complete input without understanding mode or scenario terminology.
- WeChat, email, document, and AI-tool contexts have clear low-distraction feedback.
- All HUD states keep stable layout with no clipping or jumps.
- Light, Dark, and Follow System pass screenshot and real-app acceptance.
- Esc, paste fallback, high-accuracy recognition, and DeepSeek behavior do not regress.
