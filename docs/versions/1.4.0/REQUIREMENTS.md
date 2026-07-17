# ReadyType 1.4.0 Requirements: Trending Vocabulary Packs

## Background

Users expect ReadyType to follow recent common terms like mature input methods do: newly released movie names, popular technology products, sports events, and internet phrases should work without manual import, visible friction, or degraded latency.

Publicly verifiable input-method designs point to layered vocabulary: built-in vocabulary, user vocabulary, extension dictionaries, and cloud candidates. Cloud or trending terms should supplement local candidates, not override local results.

## Product Goals

- Users should not need to manually import recent popular terms.
- Voice input must not show extra waiting, popovers, or setup burden.
- Recent proper nouns should be recognized better, especially entertainment, technology, and sports terms.
- Trending terms must not override user common words or aggressively rewrite ordinary text.
- Users can disable automatic updates, delete downloaded packs, and inspect the last update time.
- Users do not need to understand pack categories, sources, versions, or candidate counts.

## User-Facing Copy

Use "Trending Vocabulary Packs", not "cloud dictionary", "training", "model sync", or "hotword injection".

Suggested Settings copy:

- Title: Trending Vocabulary Packs
- Description: ReadyType updates recently common public terms in the background to improve recognition and cleanup. Your input content is not uploaded.
- Status: Updated / Updating / Unable to update right now / Off
- Actions: Auto-update trending terms, Update now, Delete packs

Information architecture:

- Entry: `Speech Recognition > Trending Vocabulary Packs`; do not add a sidebar destination.
- Default view: status, plain-language description, and the auto-update toggle.
- Secondary actions: reveal Update now, last update time, and delete local packs only under More.

## Scope

### 0. Fixed Data Sources

- Popularity signal: Chinese and English Wikipedia top pages and pageview metrics from the Wikimedia Analytics API.
- Canonical names: Simplified Chinese, Traditional Chinese, English labels, aliases, entity types, and date fields from Wikidata.
- The daily generation job reads the last complete calendar day and combines a 7-day popularity window with a 28-day baseline.
- Version 1.4.0 does not use TMDB, Weibo, Baidu trending lists, or other sources that require commercial licensing, lack a stable public API, or do not permit redistribution.
- The app never calls these upstream sources; it downloads only ReadyType-curated and signed packs.

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
- Download, parsing, and replacement run in the background; starting recording never performs network or disk work for packs.
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

- Apple Speech contextual strings: include at most 10-20 trending terms per request while respecting the existing 100 total contextual-candidate cap.
- AI cleanup and translation: pass only highly relevant terms as terminology hints.
- Direct dictation: use only conservative post-processing, without aggressive replacement.

### 6. Privacy and Safety

- Do not upload transcripts, final output, app names, window titles, or personal vocabulary.
- Do not embed third-party private API keys in the client.
- ReadyType-maintained generation should prepare the manifest; the client only downloads prepared packs.
- Packs require schema versioning, content hashes, and a ReadyType release-key signature. Invalid updates are rejected while the last valid pack remains active.

### 7. AI Curation Boundary

- AI participates only in the ReadyType maintainer-side offline generation job for classification, ambiguity flags, and review suggestions.
- AI cannot invent entities; first-release names and automatically published aliases must be traceable to Wikidata.
- AI output must pass schema, provenance, deduplication, category, expiration, and sensitive-term checks before entering a release candidate pack.
- AI is absent from the app's recording, recognition, and paste path and does not use the user's DeepSeek API key.
- AI-proposed new aliases go to a human review queue and are not published automatically.

## Non-Goals

- No real-time whole-web trending crawler.
- No scraping unauthorized pages or private trending APIs.
- No automatic insertion of trending terms into user common words.
- No user-input upload or training.
- No cross-app observation of post-paste edits or silent personal learning in 1.4.0.
- No complex vocabulary marketplace in this phase.
- No promise that local WhisperKit supports real-time trending-term biasing; the first phase focuses on Apple Speech contextual strings and post-processing.

## Acceptance Criteria

- Voice input still works normally when offline.
- Failed updates only show "Unable to update right now" in Settings.
- User vocabulary and confirmed learning terms outrank trending terms.
- Expired trending terms no longer participate in candidates.
- Candidate selection stays within the existing contextual vocabulary latency budget.
- Chat scenarios do not rewrite ordinary phrases into movie or product names because of trending packs.
- Turning off automatic updates keeps the current valid pack; deleting it removes its candidates.
