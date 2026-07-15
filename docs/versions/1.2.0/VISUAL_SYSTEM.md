# ReadyType 1.2.0 Visual and Motion System

## Positioning

System-level, restrained, clear, and quietly technical. Borrow low-distraction principles from Typeless and material hierarchy from Apple while keeping ReadyType's own brand color, iconography, and Chinese-first voice.

## Themes

- Follow System is the default.
- Light uses a soft gray canvas, white content layers, dark text, and low-saturation green status color.
- Dark uses a near-system-black canvas, elevated charcoal content layers, and high-contrast text.
- Semantic tokens stay consistent across themes; views do not scatter hard-coded colors.

## HUD

- Every state shares one neutral white `220 x 42 pt` capsule that does not follow the main-window appearance, preventing light/dark jumps between phases.
- Recording shows the live microphone waveform, a short status, and elapsed time. Recognition and polishing show status plus a bottom Thinking progress bar.
- The bar advances by real pipeline stage and remains below 100% until completion rather than claiming a fake exact percentage.
- A thin stroke, top highlight, neutral shadow, and restrained ReadyType green provide separation and identity.

## Motion

| State | Motion |
| --- | --- |
| Entrance | 10-12 pt rise with a 160-200 ms fade |
| Listening | Appear after an original two-tone cue; waveform follows actual input level |
| Recognizing | Keep the same shell and advance the Thinking bar through the first stage |
| Polishing | Keep the same shell, crossfade the status, and continue the progress bar |
| Complete | One green confirmation, then fade after about 900 ms |
| Copied | Amber feedback for about 1.5 seconds |
| Error | One restrained horizontal response, then stillness |

## Components and Accessibility

Use system typography and SF Symbols. Binary settings use switches, option sets use menus, and appearance uses a three-way segmented control. Cards stay at 8 pt radius or less and are not nested. Support keyboard navigation, VoiceOver labels, readable contrast, and Reduce Motion.
