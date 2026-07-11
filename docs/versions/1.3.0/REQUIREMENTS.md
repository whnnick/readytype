# ReadyType 1.3.0 Requirements: Trending Vocabulary Packs

## Background

Users expect ReadyType to follow recent common terms like mature input methods do: newly released movie names, popular technology products, sports events, and internet phrases should work without manual import, visible friction, or degraded latency.

Publicly verifiable input-method designs point to layered vocabulary: built-in vocabulary, user vocabulary, extension dictionaries, and cloud candidates. Cloud or trending terms should supplement local candidates, not override local results.

## Product Goals

- Users should not need to manually import recent popular terms.
- Voice input must not show extra waiting, popovers, or setup burden.
- Recent proper nouns should be recognized better, especially entertainment, technology, and sports terms.
- Trending terms must not override user common words or aggressively rewrite ordinary text.
- Users can disable automatic updates, delete downloaded packs, and inspect the last update time.

## User-Facing Copy

Use "Trending Vocabulary Packs", not "cloud dictionary", "training", "model sync", or "hotword injection".

Suggested Settings copy:

- Title: Trending Vocabulary Packs
- Description: ReadyType updates recently common public terms in the background to improve recognition and cleanup. Your input content is not uploaded.
- Status: Updated / Updating / Unable to update right now / Off
- Actions: Auto-update trending terms, Update now, Delete packs

## Scope

### 1. Layered Vocabulary

Priority from high to low:

1. User-added common words.
2. User-confirmed common-word suggestions.
3. ReadyType built-in product, technical, and work phrase terms.
4. Current app / scenario terms.
5. Trending vocabulary packs.

Trending packs must never outrank user vocabulary.

### 2. Background Updates

- Update automatically while idle.
- Failed updates must not show blocking alerts or affect current voice input.
- Settings keeps status and a manual update action.
- Default update frequency is at most once per day.
- Use ETag, version, or content hash to avoid redundant downloads.

### 3. Local Cache

Store packs under:

`~/Library/Application Support/ReadyType/HotVocabulary/`

Do not write packs to the repository, logs, or any upload path.

### 4. Term Metadata

Each term should include:

- `value`: display term.
- `aliases`: common aliases or mixed Chinese/English forms.
- `category`: entertainment, technology, sports, internet phrases, etc.
- `scopes`: applicable scenarios such as chat, document, or AI tool.
- `source`: public source identifier.
- `weight`: ranking weight.
- `expiresAt`: expiration time.

### 5. Dynamic Candidate Selection

Before each voice input, select only a small relevant subset:

- Apple Speech contextual strings: include at most 20-60 trending terms, while respecting the existing 100 total candidate cap.
- AI cleanup and translation: pass only highly relevant terms as terminology hints.
- Direct dictation: use only conservative post-processing, without aggressive replacement.

### 6. Privacy and Safety

- Do not upload transcripts, final output, app names, window titles, or personal vocabulary.
- Do not embed third-party private API keys in the client.
- ReadyType-maintained generation should prepare the manifest; the client only downloads prepared packs.
- Packs need schema versioning and content hashes; signing can be added later.

## Non-Goals

- No real-time whole-web trending crawler.
- No scraping unauthorized pages or private trending APIs.
- No automatic insertion of trending terms into user common words.
- No user-input upload or training.
- No complex vocabulary marketplace in this phase.
- No promise that local WhisperKit supports real-time trending-term biasing; the first phase focuses on Apple Speech contextual strings and post-processing.

## Acceptance Criteria

- Voice input still works normally when offline.
- Failed updates only show "Unable to update right now" in Settings.
- User vocabulary and confirmed learning terms outrank trending terms.
- Expired trending terms no longer participate in candidates.
- Candidate selection stays within the existing contextual vocabulary latency budget.
- Chat scenarios do not rewrite ordinary phrases into movie or product names because of trending packs.
