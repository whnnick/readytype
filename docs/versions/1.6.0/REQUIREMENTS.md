# ReadyType 1.6.0 Requirements

## Problem

ReadyType can infer several app and semantic scenarios, but the rules are distributed, chat tone remains coarse, and users cannot speak an instruction against the currently selected text. Adding more visible modes increases cognitive load, while accumulating app-specific and phrase-specific patches is not maintainable.

Typeless publicly emphasizes selection-aware voice editing, per-app tone, and a personal dictionary. Qianwen Input Method emphasizes spoken cleanup, structured formatting, mixed Chinese/English recognition, and low interaction cost. ReadyType 1.6.0 adopts these product principles without copying brand assets, interface details, or full feature scope.

## Product Goals

1. Produce context-appropriate output without requiring users to select email, chat, or document first.
2. Let users modify, translate, or reply to selected text with natural spoken instructions.
3. Never damage selected text or write into the wrong app after a recognition or AI failure.
4. Reuse the existing DeepSeek, HUD, shortcut, vocabulary, and delivery pipelines without introducing a second model-cost source.
5. Make decisions testable, explainable, and degradable instead of maintaining phrase-specific patches.

## User-visible Capabilities

### P0: Voice Actions on Selected Text

- If non-empty text is selected before activation, ReadyType captures an ephemeral selection context.
- Explicit actions include shorten, expand, change tone, organize, translate to English, and draft a reply.
- Ordinary dictated content still replaces the selection as normal dictation and does not force an AI call.
- Selection actions require DeepSeek. If unavailable, the original remains unchanged and the HUD shows an actionable error.
- Selected text is capped at 8,000 characters per action; larger selections are rejected before transmission.

### P0: Unified Context Understanding

- Support seven app profiles: personal chat, work chat, email, notes, documents, AI tools, and generic.
- Inputs include explicit spoken intent, selection state, manual settings, frontmost app category, window type, and transcript semantics.
- Fixed priority: explicit spoken command > selection intent > manual setting > app profile > semantic inference > generic.
- Personal chat must not add formal email language by default.
- Email structure is used only when the environment or spoken intent is clearly email-related, and must not invent recipients, dates, attachments, or commitments.
- AI-tool output keeps the existing task, background, constraints, and deliverable structure.

### P0: Safe Replacement and Fallback

- Capture an ephemeral fingerprint of target app, accessibility element, selected text, and range at activation.
- Revalidate app, focus, and selected text before writing.
- Replace in place only when the target is unchanged.
- If the target changed or cannot be verified, overwrite nothing; copy the result and show “Target changed. Result copied.”
- Never infer selected text from the clipboard or poll text in other apps.

### P1: Context Feedback and Manual Fallback

- Keep the compact HUD without a permanent scenario badge.
- For selection actions only, the listening copy becomes “Say how you want to change it.”
- Preserve existing manual output and scenario controls as a fallback when automatic inference is wrong.
- Recent-result details may show user-facing context such as “Personal chat / More natural,” but not confidence values or internal terminology.

## Data and Privacy

- Selected text is sent to DeepSeek only after explicit user activation and an AI selection action.
- Direct dictation never sends selected text merely because a selection exists.
- Selection context remains in memory for one workflow and is never persisted.
- Analytics must never include audio, transcript, output, selected text, window title, bundle identifier, clipboard content, or DeepSeek keys.
- Allowed analytics: action type, app-profile category, success/fallback/cancel, fixed error code, length bucket, and latency bucket.

## Acceptance Criteria

- One pure decision entry point owns context priority and is covered by unit tests.
- Real-app acceptance covers at least six categories: WeChat or QQ, Feishu or Slack, Mail or Gmail, TextEdit or Pages, Obsidian or Notes, and ChatGPT or Codex.
- Shorten, naturalize, translate, and reply actions replace selected text correctly.
- A changed selection is never overwritten and always uses clipboard fallback.
- Personal-chat negative cases contain no email salutation or closing; email cases invent no facts.
- Local context classification P95 is below 10ms and selection capture/revalidation P95 below 50ms. Network AI latency is observed but is not a local performance gate.
- Automatic recognition prefers local high accuracy for speech of at least eight seconds. Fast and high-accuracy backends run concurrently, with no more than a three-second high-accuracy budget and no serial fast retry after timeout.
- Cleanup, translation, and AI-prompt output use DeepSeek non-thinking mode with a bounded output length. Recent results expose recognition and processing/delivery timing separately.
- Contextual terms selected for recognition continue into AI processing as at most 20 canonical-spelling candidates. They remain hints rather than body content and replace an ever-growing static misrecognition catalog.
- Full tests, build, UI smoke, sensitive-data scan, ZIP/DMG checks, and real-app black-box acceptance must pass before release.

## Non-goals

- No monitoring of later user edits and no true cross-session self-learning.
- No automatic reading of full pages, emails, or chat history; only explicit selections are processed.
- No input history, cloud sync, dialect expansion, additional output languages, extra shortcut modes, or new model providers.
- In-place replacement is not promised for every app; unsupported targets must fall back safely to copy.
