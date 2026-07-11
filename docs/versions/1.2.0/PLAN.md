# ReadyType 1.2.0 Implementation Plan: UI/UX Refresh

## Principles

1. Freeze interaction before writing SwiftUI.
2. Establish the design system before replacing screens.
3. Do not rewrite the business pipeline during the UI refresh.
4. Keep a runnable build and matching regression gate at every stage.
5. Review every high-fidelity screen with the user and obtain explicit approval; do not modify application UI code until the user says, "UI approved, proceed with development."

## Phases

### 1. High-Fidelity Prototype

Design Home, Common Words, Language and Output, Speech Recognition, Permissions and Privacy, and every HUD state in Figma/Open Design. Include Light, Dark, theme switching, a clickable primary flow, and motion annotations. Explain each screen's information structure, interaction, states, and tradeoffs, then iterate until the user records explicit design approval.

### 2. Design System

Refactor semantic colors, materials, spacing, typography, and component states in `DesignSystem.swift`. Refactor HUD timing and Reduce Motion behavior in `MotionTokens.swift`. Add a persisted appearance preference that defaults to Follow System.

### 3. HUD

Refactor `RecordingHUDView` and window sizing first. Validate entrance, listening, recognizing, polishing, outputting, success, copied fallback, cancellation, and error in real apps while preserving Esc and paste behavior.

### 4. Main Window and Menu Bar

Replace Console with a Home summary, split the oversized Settings surface, and keep only frequent actions and status in the menu-bar popover.

### 5. App Awareness

Reuse existing foreground-app and scenario capabilities to expose user-readable context labels. Uncertain cases use generic cleanup and retain current output-safety constraints.

### 6. Acceptance and Release

Add unit tests for appearance preferences, state presentation, and automatic context mapping. Cover Light, Dark, Reduce Motion, multiple display sizes, and real input in chat, document/email, and AI-tool apps. Produce bilingual 1.2.0 black-box acceptance documents.

## Gates

- `swift test`
- `scripts/build-app.sh`
- UI text and screenshot gates
- Real WeChat, Mail/TextEdit, and AI-tool input
- Esc, automatic paste, clipboard fallback, high-accuracy recognition, and DeepSeek regression

## Definition of Done

Version 1.2.0 is releasable only after the high-fidelity prototype is approved, all three appearance choices work, every HUD state passes, the main window is simplified, and the core input pipeline has no regression.
