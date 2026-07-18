# ReadyType 1.4.0 Interaction Flow: Trending Vocabulary Packs

## 1. User-Visible Interaction

Goal: enabled silently by default; users see Trending Vocabulary Packs only when checking status or requesting an update.

```mermaid
flowchart TD
    A["User opens ReadyType"] --> B["Console keeps the existing voice input experience"]
    B --> C{"Does the user open Settings?"}
    C -- "No" --> D["Background checks packs while idle"]
    D --> E["User continues double-press Option voice input"]
    C -- "Yes" --> F["Speech Recognition > Trending Vocabulary Packs"]
    F --> G["Show status: Not updated / Updating / Automatically updated / Unable to update right now"]
    G --> H{"User action"}
    H -- "Keep default" --> I["Background keeps terms current"]
    H -- "Update now" --> J["Start background update without blocking input"]
    J --> G
```

## 2. Background Update Interaction

Goal: failed updates do not show alerts, interrupt recording, or affect automatic paste.

```mermaid
stateDiagram-v2
    [*] --> WaitingIdle: Delayed check after app launch
    WaitingIdle --> Skipped: Recording/transcribing/processing/outputting
    Skipped --> WaitingIdle: Back to idle
    WaitingIdle --> CheckNeeded: Last check was more than one day ago
    WaitingIdle --> NoCheck: Already checked today
    CheckNeeded --> Downloading: Update in background
    Downloading --> Updated: Hash and signature are valid; atomic replacement succeeds
    Downloading --> KeepOld: Download fails but old packs exist
    Downloading --> Unavailable: Download fails and no local pack exists
    Updated --> [*]: Settings shows updated
    KeepOld --> [*]: Keep old packs; Settings shows unable to update right now
    Unavailable --> [*]: No candidates; Settings shows unable to update right now
    NoCheck --> [*]
```

## 3. Candidate Decision During Voice Input

Goal: trending terms are low-priority supplements and must not pollute user vocabulary or ordinary expressions.

```mermaid
flowchart TD
    A["User double-presses Option"] --> B["Read current app and writing scenario"]
    B --> C["Load in-memory vocabulary index"]
    C --> D["Merge candidates: user words + confirmed suggestions + built-in terms + scenario terms + trending terms"]
    D --> E["Filter expired trending terms"]
    E --> F["Rank by priority"]
    F --> G["User terms have highest priority"]
    F --> H["Trending terms stay low priority; scenario match can boost them"]
    G --> I["Cap Top N; total candidates stay under 100"]
    H --> I
    I --> J{"Recognition route"}
    J -- "Apple Speech" --> K["Pass as contextualStrings"]
    J -- "High-accuracy speech package" --> L["No promise of real-time trending-term bias; conservative post-processing only"]
    J -- "AI output modes" --> M["Pass highly relevant terms as DeepSeek terminology hints"]
    K --> N["Generate transcript and final output"]
    L --> N
    M --> N
    N --> O["Auto-paste or clipboard fallback"]
```

## 4. Settings Information Structure

```mermaid
flowchart LR
    A["Sidebar: Speech Recognition"] --> B["Recognition mode"]
    A --> C["High-accuracy speech package"]
    A --> D["Trending Vocabulary Packs"]
    D --> E["Show: status, source, and privacy explanation"]
    D --> F["Action: Update now"]
    D --> G["Copy: your input content is not uploaded"]
```

## Interaction Principles

- The normal voice input path adds no new popovers.
- Trending pack updates must not block input after double-pressing `Option`.
- Settings only shows user-readable states, not API, manifest, or hash details.
- Do not expose pack versions, category switches, file locations, or deletion controls.
- Failed updates keep the previous valid pack; without one, existing recognition remains unchanged.
