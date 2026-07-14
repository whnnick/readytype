# ReadyType 1.4.0 Interaction Flow: Trending Vocabulary Packs

## 1. User-Visible Interaction

Goal: enabled silently by default; users only see Trending Vocabulary Packs when they open Settings to inspect or manage them.

```mermaid
flowchart TD
    A["User opens ReadyType"] --> B["Console keeps the existing voice input experience"]
    B --> C{"Does the user open Settings?"}
    C -- "No" --> D["Background checks packs while idle"]
    D --> E["User continues double-press Option voice input"]
    C -- "Yes" --> F["Settings > Trending Vocabulary Packs"]
    F --> G["Show status: Updated / Updating / Unable to update right now / Off"]
    G --> H{"User action"}
    H -- "Keep default" --> I["Auto-update stays on; background handles it"]
    H -- "Update now" --> J["Start background update without blocking input"]
    H -- "Turn off auto-update" --> K["Stop future automatic checks; keep local packs"]
    H -- "Delete packs" --> L["Delete local trending packs; candidates are removed immediately"]
    J --> G
    K --> G
    L --> G
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
    CheckNeeded --> Downloading: Auto-update is on
    CheckNeeded --> Off: Auto-update is off
    Downloading --> Updated: Download succeeds and hash is valid
    Downloading --> KeepOld: Download fails but old packs exist
    Downloading --> Unavailable: Download fails and no local pack exists
    Updated --> [*]: Settings shows updated
    KeepOld --> [*]: Keep old packs; Settings shows unable to update right now
    Unavailable --> [*]: No candidates; Settings shows unable to update right now
    NoCheck --> [*]
    Off --> [*]
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
    A["Settings"] --> B["Recognition"]
    A --> C["DeepSeek"]
    A --> D["Output"]
    A --> E["Common Words"]
    A --> F["Trending Vocabulary Packs"]
    F --> G["Auto-update toggle"]
    F --> H["Status and last updated time"]
    F --> I["Update now"]
    F --> J["Delete packs"]
    F --> K["Copy: your input content is not uploaded"]
```

## Interaction Principles

- The normal voice input path adds no new popovers.
- Trending pack updates must not block input after double-pressing `Option`.
- Settings only shows user-readable states, not API, manifest, or hash details.
- Deleting packs only affects trending candidates, not user common words.
- Turning off auto-update keeps already downloaded packs; deleting them removes them from candidates.
