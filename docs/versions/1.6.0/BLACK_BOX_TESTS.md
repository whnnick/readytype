# ReadyType 1.6.0 Black-box Acceptance

## Current Status

Planning is complete and Phases 1, 2, and 2.1 are implemented. This file is the release contract; implementation may update status and evidence but must not weaken acceptance targets.

| Requirement | Status | Release Evidence |
| --- | --- | --- |
| Single Context Engine | Complete | 18 focused and 409 full-suite tests pass; classification P95 is 0.062ms; production build passes. |
| Personal/work chat tone | Not started | Positive, negative, and real-app output pending. |
| Email, notes, documents, and AI-tool structure | Not started | No-invention and formatting evidence pending. |
| Spoken selected-text actions | Not started | Shorten, naturalize, translate, and reply pending. |
| Selection capture and safe replacement | Complete | 32 focused tests cover capture limits, app, focus, range and text changes, and diagnostic path restrictions; fixed-fixture TextEdit replacement passes; fingerprint validation P95 is 0.000ms. |
| Safe fallback after target changes | Partial | Automated app, focus, range, and text changes all copy without attempting a write; real cross-app change acceptance remains for Phase 5. |
| Long-form recognition and output latency | Partial | The eight-second route boundary, concurrent engines, three-second budget, non-thinking DeepSeek request, 20 canonical-spelling candidates, and segmented timing pass. A fixed 35.9-second recording measured 4,445ms for fast recognition, 5,240ms for warm local high-accuracy decoding, and 7,036ms for processing/delivery. Both ASR paths contained proper-name errors, so the accuracy gate is not complete. A second acoustic run contained excessive silence and is retained only as a pipeline check, not A/B performance evidence. |
| Privacy and anonymous analytics | Not started | Allowlist and network inspection pending. |
| Automated and release gates | Partial | All 423 tests pass and the production `.app` builds; final UI, sensitive scan, and release artifacts remain pending. |

## Fixed Real-app Matrix

| Category | Preferred App | Allowed Alternative |
| --- | --- | --- |
| Personal chat | WeChat | QQ / Messages |
| Work chat | Feishu | Slack / Teams |
| Email | Mail | Gmail / Outlook |
| Document | TextEdit | Pages / Word |
| Notes | Notes | Obsidian / Notion |
| AI tool | Codex | ChatGPT / Claude |

## Required Failure Paths

- Switch apps while processing.
- Change or clear the selection while processing.
- Current app cannot read or replace the selection.
- Missing DeepSeek key, quota exhaustion, rate limit, network loss, and service error.
- Selected text exceeds 8,000 characters.
- Press `Esc` or click close while recording.
- Both engines contain proper-name errors, or high accuracy adds a trailing hallucination absent from the fast result.

## Release Blockers

Spoken selected-text actions, context tone, the complete real-app matrix, and final release gates remain incomplete, so 1.6.0 is not releasable.
