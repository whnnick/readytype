# ReadyType 1.5.0 Requirements

## Problem

The existing sidebar mixes frequent product destinations with low-frequency configuration, creating too many entries and weakening the Home hierarchy. Users should quickly reach voice input, usage information, or Common Words without permanently seeing connection, shortcut, and permission destinations.

## Requirements

1. Primary navigation contains only Home, Usage Overview, Common Words, and Settings.
2. Settings is pinned to the bottom of the sidebar and uses the standard gear icon.
3. Settings provides five stable categories: General, Speech Recognition, Shortcuts, Permissions & Privacy, and About.
4. Appearance selection moves from the sidebar into General settings.
5. High-accuracy speech-package prompts still open Speech Recognition inside Settings.
6. System, Light, and Dark appearances remain available.
7. This milestone changes navigation and page ownership only; it removes no feature and changes no user data.

## Acceptance Criteria

- Language & Output, Shortcuts, Speech Recognition, Permissions & Privacy, and About no longer appear as separate sidebar destinations.
- Every moved feature remains reachable inside Settings.
- Unit tests and a real-app UI smoke gate cover the new navigation structure.
