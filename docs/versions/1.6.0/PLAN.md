# ReadyType 1.6.0 Implementation Plan

## Success Definition

Success is not measured by adding controls. It is measured by fewer manual scenario choices, safe selected-text actions, and chat/email output that clearly fits real app context.

## Phase 0: Freeze the Baseline

- Record 1.5.0 anonymous adoption, scenario, completion, cancellation, fixed-error, and completion-latency buckets.
- Never read or export user text.
- Freeze the 1.6.0 black-box utterances and six-category app matrix before implementation.

Evidence: a content-free baseline snapshot and agreed primary metrics.

Current evidence: the anonymous field contract and fixed app acceptance matrix are frozen. Production volume is still insufficient for defensible adoption conclusions, so the snapshot remains pending real cohort data.

## Phase 1: Unified Context Engine

1. Add `AppProfile`, `InputIntent`, `OutputTone`, `ContextReason`, and `ContextDecision`.
2. Move existing scenario and chat-tone inference behind one decision entry point.
3. Centralize app mappings in `AppProfileCatalog` with a generic fallback.
4. Preserve current UI and output behavior while validating new/old compatibility.
5. Remove only duplicate inference created by this migration.

Verification: priority, mapping, semantic fallback, compatibility, and P95 < 10ms tests.

Status: complete. The new `ContextEngineTests` and legacy `OutputScenarioTests` pass 18 focused cases; the full 409-test suite has no failures, classification P95 is 0.062ms, and the production `.app` build succeeds.

## Phase 2: Selection Capture and Safe Replacement

1. Add `ActiveTextContextProvider` for explicit selections only.
2. Add `SelectionFingerprint` and `SelectionReplacementGuard`.
3. Extend selection capabilities around `PasteService` without changing normal paste behavior.
4. Cover unchanged selection, changed selection, focus change, app switch, inaccessible elements, and oversized text.
5. Every failed validation copies instead of overwriting.

Verification: unit tests, TextEdit integration, zero wrong-window writes, and P95 < 50ms selection overhead.

Status: complete. Explicit selection capture, target/selection fingerprints, guarded replacement, and copy-only fallback are implemented. All 32 focused and 420 full-suite tests pass, fingerprint validation P95 is 0.000ms, the fixed-fixture TextEdit replacement acceptance passes, and the production `.app` builds. The diagnostic entry point requires an explicit environment opt-in and is inactive during normal launches.

## Phase 3: Spoken Selection Actions

1. Add a bounded set: shorten, expand, naturalize, formalize, organize, translate to English, and reply.
2. Enter selection-AI processing only for explicit intent; ordinary dictation keeps the existing path.
3. Reuse the DeepSeek provider and existing error mapping.
4. Preserve facts, names, numbers, dates, and commitments.
5. DeepSeek failure never falls back by overwriting the original with ordinary text.

Verification: contract tests, original-preservation tests, 8,000-character cap, and API-failure coverage.

## Phase 4: Context Tone and HUD

1. Add positive and negative fixtures for personal chat, work chat, email, notes, documents, and AI tools.
2. Make prompts consume `ContextDecision`; call sites stop re-inferring scenarios.
3. Change only HUD copy for selection actions, preserving capsule geometry and visual design.
4. Show user-readable context in recent results while preserving manual fallback.
5. Add anonymous action, profile, outcome, length-bucket, and latency-bucket fields.

Verification: prompt tests, HUD state tests, analytics allowlist tests, and six-category UI smoke.

## Phase 5: Real-app Acceptance and Release

- Run normal input, selected-text edit, changed-target, and cancellation paths across six app categories.
- Cover Chinese, English, and mixed input; include negative cases for personal chat and email.
- Run `swift test`, `scripts/build-app.sh`, `scripts/verify-ui.sh`, `scripts/verify-release-local.sh`, and `python3 scripts/check-sensitive-info.py`.
- Synchronize bilingual README, changelog, version docs, and black-box acceptance.
- Change app/build versions only when a testable development build exists. Planning leaves the public app at 1.5.0.
- Verify GitHub Actions, latest Release, DMG, ZIP, and SHA-256 after publishing.

## Expected Development Rounds

1. Context Engine and compatibility tests.
2. Selection capture, fingerprint, and safe replacement.
3. Selection actions and DeepSeek processing.
4. Context tone, HUD, and anonymous analytics.
5. Cross-app acceptance, fixes, packaging, and release.

Each round requires independent evidence. A defect may receive one architectural correction and one regression pass, not an unbounded phrase-by-phrase loop.

## Release Gates

- All P0 requirements complete; deferred P1 items explicitly documented.
- No automated test failures; external skips have stated reasons.
- Changed-selection and wrong-window protections pass 100%.
- The real-app matrix is complete with evidence.
- No user content, credentials, private paths, or internal assets are exposed.

## 1.7.0 Candidate

- Use short-lived, range-bounded local diffing after users edit text just delivered by ReadyType.
- Suggest only after a correction repeats, and save it only after confirmation.
- Support undo, ignore, and delete without storing full input content.

This candidate does not block 1.6.0 and must not be implemented implicitly in this release.
