# ReadyType 1.5.1 Requirements

## Scope

1. Reduce long-form waiting by running fast and high-accuracy recognition concurrently after eight seconds.
2. Keep automatic recognition within the existing three-second high-accuracy budget and reuse completed work instead of retrying serially.
3. Use bounded engine-specific quality signals without directly comparing incompatible raw scores.
4. Pass a bounded canonical vocabulary list to AI cleanup and use general spelling guidance instead of phrase-specific replacements.
5. Disable DeepSeek thinking, bound output size, and report recognition latency separately from processing and delivery latency.
6. Do not expose unfinished 1.6.0 selected-text actions.

## Acceptance Criteria

- Full automated tests, production build, signature checks, packaging, UI gate, and sensitive-information scan pass.
- The release workflow publishes matching ZIP, DMG, and SHA-256 assets.
- Public version and build are `1.5.1 (96)`.
