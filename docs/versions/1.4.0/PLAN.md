# ReadyType 1.4.0 Plan: Trending Vocabulary Packs

## Design Principles

1. Silent for users: background updates, quiet failures, no input waiting.
2. User-controlled: Settings can disable, update now, and delete packs.
3. Local-first: voice input must work without network access.
4. Layered vocabulary: user terms always win; trending terms are low-priority supplements.
5. Small candidate sets: select relevant Top N terms, never pass whole packs to recognition.
6. Expiration: trending terms must expire to avoid long-term candidate pollution.

## Mature Input Method Pattern

- Fcitx CloudPinyin publicly describes a web-backed extra candidate for Pinyin input; this is the right pattern for cloud/trending terms as supplemental candidates.
- Fcitx5 Chinese input uses local input method backends such as libime, showing that stable input depends on local models/dictionaries rather than network requests per input.
- Rime/librime is centered on local dictionaries, user data, and configurable schemes, which is the right reference for local-first and user-vocabulary behavior.

ReadyType should borrow these patterns without copying Pinyin IME internals. ReadyType is speech-first, so trending terms mainly feed:

- Apple Speech `contextualStrings`.
- Conservative post-recognition term correction.
- DeepSeek terminology hints for AI output modes.

## Fixed Sources

- Wikimedia Analytics API: top pages and pageview metrics for `zh.wikipedia.org` and `en.wikipedia.org`.
- Wikidata: canonical names, language aliases, entity types, and date fields; its structured data is CC0.
- The first release does not use TMDB. Its free developer API terms do not cover commercial products unless a commercial license is obtained later.
- See [Pack Generation and AI Curation](./VOCABULARY_PIPELINE.md) for source, license, and API details.

## Technical Architecture

```text
ReadyType built-in vocabulary
+ user common words
+ confirmed learning terms
+ in-memory trending vocabulary snapshot
        ↓
SmartTermDictionary merge
        ↓
ContextualVocabularyProvider rank and cap
        ↓
Apple Speech contextualStrings / post-processing / DeepSeek terminology hints
```

## New Modules

- `HotVocabularyManifest`: decodable manifest with release-signature verification.
- `HotVocabularyStore`: atomic writes, last-valid-version retention, expiration cleanup, and an in-memory snapshot.
- `HotVocabularyUpdater`: idle-time download with ETag, hash, and signature validation.
- `SmartTermDictionary.mergingHotVocabulary`: merges valid trending terms into the existing unified dictionary at low priority.
- `HotVocabularySettingsViewModel`: exposes only user-readable state and actions inside Speech Recognition.

## Data Format

The remote entry point is a small manifest and the terms live in a separate content file. The signature covers the schema, version, generated/expiry timestamps, minimum app version, and content hash. The client must verify both SHA-256 and Ed25519 before switching the active version.

```json
{
  "schemaVersion": 1,
  "packVersion": "2026.07.07",
  "generatedAt": "2026-07-07T00:00:00Z",
  "expiresAt": "2026-08-07T00:00:00Z",
  "minimumAppVersion": "1.4.0",
  "contentPath": "pack.json",
  "contentSHA256": "<sha256>",
  "signature": "<ed25519-signature>"
}
```

Pack content format:

```json
{
  "packVersion": "2026.07.07",
  "terms": [
    {
      "value": "Example Movie Title",
      "aliases": ["example movie", "示例电影"],
      "category": "movie",
      "scopes": ["chat", "document"],
      "sourceID": "wikidata:Q000000",
      "weight": 70,
      "expiresAt": "2026-08-07T00:00:00Z"
    }
  ]
}
```

## Update Strategy

- Check after app launch with a delay; never block first paint.
- Update only while idle, not while recording or outputting text.
- Check at most once per day by default.
- Keep the old pack if download fails; show missing only if no local pack exists.
- Network failures do not show alerts; Settings shows "Unable to update right now".
- Download into a temporary file and atomically replace the active pack only after every validation succeeds; retain the last valid pack on any failure.
- Build one immutable in-memory snapshot at launch; the recording path reads that snapshot without network or disk access.
- The maintainer-side job reads the last complete calendar day and combines a 7-day popularity window with a 28-day baseline. The client never calls upstream APIs directly.

## Publishing and Trust

- A separate ReadyType publishing workflow generates packs; the client never scrapes trending lists.
- Generated files are deployed through GitHub's official Pages Artifact workflow without writing generated files into a source branch. The stable entry point is `https://whnnick.github.io/readytype/vocabulary/v1/manifest.json`.
- Sign manifests and content with a fixed private key while the app embeds only the public key; repositories and CI must not store the production private key in plaintext.
- Publishing validates source licenses, duplicates, sensitive terms, and expiration before generating hashes, signatures, and versions.
- Version 1.4.0 must establish a stable, rollback-capable production pack URL and release check before the updater ships; no temporary URL is embedded in the app.

## AI Curation

- AI runs only in the maintainer-side generation workflow, never in the app hot path, and never with the user's API key.
- First-release automatically published names and aliases must come from Wikidata. AI performs classification review, ambiguity flags, and review suggestions.
- AI-proposed new aliases can only enter a human review queue; they cannot be published directly.
- The published result must remain reproducible and verifiable by deterministic scripts with AI disabled.

## Ranking Strategy

Base priority:

- User-added words: highest.
- User-confirmed suggestions: high.
- Built-in terms: medium-high.
- Scenario terms: medium.
- Trending terms: low.

Trending-term adjustments:

- Boost matching scenarios, such as entertainment in chat contexts.
- Filter expired terms.
- Prefer fresh terms.
- If the user confirms a trending term as a common word, move it into user vocabulary and stop treating it as trending-only.

## Performance Budget

- Parse local packs in the background.
- Before recognition, only filter in memory; no network call.
- Candidate selection should stay within the existing `ContextualVocabularyProvider` budget.
- Apple Speech contextual terms must stay under 100 total terms.
- Trending terms are capped at 10-20 per request, with a lower cap for chat scenarios to reduce false corrections.

## Implementation Steps

1. Completed: freeze the 1.4.0 sources, AI boundary, publishing endpoint, and UI direction.
2. Completed: add manifest, Ed25519 validation, atomic storage, and previous-valid-version fallback tests without networking.
3. Completed: merge valid packs into the unified dictionary as a low-priority `SmartTermSource` while keeping Common Words at the highest priority.
4. Completed: cap trending terms at 20 per request, filter individual expired terms, and prevent trending aliases from triggering automatic post-recognition replacement.
5. Completed: add a compact section inside Speech Recognition without a new sidebar destination or technical version dates.
6. Completed: the updater supports same-origin HTTPS downloads, ETag, one automatic check per day, forced manual checks, and last-valid-pack retention; production signing, deterministic generation, Pages deployment, and the app's in-memory dictionary integration are complete.
7. Completed: add atomic replacement, rollback, offline, and performance tests; the live pack has been downloaded from the public endpoint and accepted by the app's own verifier.
8. Run real voice regression: with trending terms, without trending terms, expired terms, and chat false-positive cases.

## Follow-Up Release

- Personal correction memory, cross-session counters, and confirm-first learning are candidates for 1.5.0.
- Version 1.4.0 does not observe user edits in other apps, upload personal corrections, or perform silent learning.

## Verification Commands

- `swift test --filter HotVocabulary`
- `swift test --filter ContextualVocabularyProviderTests`
- `swift test --filter ContextualVocabularyLatencyBudgetTests`
- `swift test`
- `scripts/build-app.sh`

## Real Acceptance

- Voice input still works offline.
- Update failures do not interrupt input.
- User vocabulary outranks same-name or near-sound trending terms.
- Entertainment terms help in relevant contexts but do not pollute technical documents.
- Deleting packs removes their candidates immediately.
