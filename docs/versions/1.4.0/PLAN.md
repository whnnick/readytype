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

## Technical Architecture

```text
ReadyType built-in vocabulary
+ user common words
+ confirmed learning terms
+ local trending vocabulary cache
        ↓
SmartTermDictionary merge
        ↓
ContextualVocabularyProvider rank and cap
        ↓
Apple Speech contextualStrings / post-processing / DeepSeek terminology hints
```

## New Modules

- `HotVocabularyTerm`: trending term model.
- `HotVocabularyManifest`: pack manifest with version, generation time, category, and hash.
- `HotVocabularyStore`: local read/write, expiration cleanup, and pack deletion.
- `HotVocabularyUpdater`: background download, ETag/hash checks, and failure state.
- `HotVocabularyProvider`: selects Top N terms based on app, scenario, and weight.
- `HotVocabularySettingsViewModel`: Settings state, toggle, and manual update action.

## Data Format Draft

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-07-07T00:00:00Z",
  "packs": [
    {
      "id": "entertainment-cn",
      "displayName": "Entertainment",
      "version": "2026.07.07",
      "terms": [
        {
          "value": "Example Movie Title",
          "aliases": ["example movie"],
          "category": "movie",
          "scopes": ["chat", "document"],
          "source": "public-curated",
          "weight": 70,
          "expiresAt": "2026-08-07T00:00:00Z"
        }
      ]
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
- If a server exists later, the server aggregates TMDb, Wikidata, public lists, or manual curation. The client must not call third-party APIs directly.

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
- Chat scenarios should use a lower cap to reduce false corrections.

## Implementation Steps

1. Add 1.4.0 documents and scope boundaries.
2. Add local data models and store tests without networking.
3. Merge packs into `SmartTermDictionary` as a low-priority `SmartTermSource`.
4. Extend `ContextualVocabularyProvider` and test ranking/capping.
5. Add Settings toggle, status, and deletion action.
6. Add background updater, starting with local or GitHub-hosted manifests.
7. Add sample packs and performance tests.
8. Run real voice regression: with trending terms, without trending terms, expired terms, and chat false-positive cases.

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
