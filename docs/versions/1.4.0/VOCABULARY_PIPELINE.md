# ReadyType 1.4.0 Pack Generation and AI Curation

## Goal

Generate public trending vocabulary packs with explicit provenance, reproducible output, and rollback support. AI may improve maintainer efficiency, but it cannot become a real-time input dependency or bypass deterministic validation to publish terms.

## Fixed Data Sources

### Wikimedia Analytics API

- Purpose: obtain top pages and pageview metrics for Chinese and English Wikipedia.
- Projects: `zh.wikipedia.org` and `en.wikipedia.org`.
- Timing: read the previous complete calendar day and retain 7-day and 28-day aggregates.
- Official documentation: [Wikimedia Analytics API](https://doc.wikimedia.org/generated-data-platform/aqs/analytics-api/) and [Page Views API](https://doc.wikimedia.org/generated-data-platform/aqs/analytics-api/reference/page-views.html).

### Wikidata

- Purpose: map popular pages to entities and obtain Simplified Chinese, Traditional Chinese, and English labels, aliases, entity types, and date fields.
- License: structured data is CC0 and can be used commercially and redistributed.
- Official documentation: [Wikidata Licensing](https://www.wikidata.org/wiki/Wikidata:Licensing) and [Data Access](https://www.wikidata.org/wiki/Help:Data_access).

### Explicit First-Release Exclusions

- TMDB: its free developer API terms cover non-commercial use; ReadyType will not integrate it without a commercial license. See the [TMDB FAQ](https://developer.themoviedb.org/docs/faq).
- Weibo, Baidu trending lists, and unofficial scraping APIs: no stable public interface or clear redistribution permission.
- User input, personal common words, and window content: never used as public trending sources.

## Daily Generation Flow

```text
Read the previous complete day of Pageviews
        ↓
Combine 7-day popularity with a 28-day baseline
        ↓
Remove home, date, list, disambiguation, and unmapped pages
        ↓
Join Wikidata names, aliases, types, and dates
        ↓
Filter allowed categories and compute a trend score
        ↓
Optional AI classification review and ambiguity flags
        ↓
Deterministic validation, deduplication, expiration, and negative tests
        ↓
Generate hash, sign, and publish
```

Candidates must:

- Map to a Wikidata entity.
- Belong to an allowed category such as entertainment, technology products, people, sports events, or organizations.
- Show sustained activity within the last 7 days or a clear increase over the 28-day baseline.
- Have a canonical label for the active output language.
- Avoid sensitive, advertising, ambiguous-conflict, and manually blocked terms.

Ranking uses mature frequent-item and time-decay ideas. The first release uses explainable counts, a 7-day window, and a 28-day baseline rather than an opaque online model. See the [Space-Saving frequent-items work](https://www.cs.ucsb.edu/research/tech-reports/2005-23).

## AI Curation Boundary

AI may:

- Review entity classification.
- Flag ambiguity, promotional content, and candidates unsuitable for an input tool.
- Suggest aliases and reasoning for human review.

AI may not:

- Create automatically published terms without a Wikidata entity.
- Directly change weight, expiration, or signed artifacts.
- Publish newly generated aliases without human review.
- Read user audio, transcripts, window content, or personal vocabulary.
- Run when a user starts voice input.

The generation script must still fetch, map, filter, package, and validate with AI disabled. AI failure can reduce auxiliary review information but cannot block the base pack.

## Publishing and Security

- Publish generated files from this repository's `gh-pages` branch, separate from application-source history.
- Planned entry point: `https://whnnick.github.io/readytype/vocabulary/v1/manifest.json`.
- The manifest includes schema version, pack version, generation time, content hash, signature, and minimum compatible app version.
- Use Ed25519 signatures; the app embeds only the public key.
- Download to a temporary file and atomically replace the active pack only after all validation passes; keep the last valid pack on failure.
- Store the private signing key and DeepSeek key only in maintainer-controlled encrypted publishing infrastructure, never in the repository, logs, or release artifacts.

## App Runtime Boundary

- Check for updates at most once per day and only while idle.
- The recording path reads only a parsed in-memory snapshot.
- Select at most 10-20 trending terms per request while keeping total contextual candidates under Apple's recommended cap of 100. See [Apple contextualStrings](https://developer.apple.com/documentation/speech/analysiscontext/contextualstrings).
- Trending terms rank below user common words and confirmed learning terms.
- Direct dictation does not apply aggressive forced replacement from trending terms.

## Release Gates

- Source and license checks pass.
- The same input produces the same deterministic result.
- A valid base pack is generated when AI is disabled or unavailable.
- The app rejects corrupted, expired, invalid-signature, and unsupported-schema packs.
- General negative-set accuracy does not materially regress.
- Chat, email, document, and technical-content false-trigger tests pass.

## Personal Learning Boundary

Personal correction memory is separate from public trending packs. It requires cross-app edit detection, conflict handling, undo, and privacy controls, so it remains an independent 1.5.0 design. Version 1.4.0 continues to use the existing user-confirmed common-word mechanism.
