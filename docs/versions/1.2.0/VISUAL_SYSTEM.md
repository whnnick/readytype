# ReadyType 1.2.0 Visual and Motion System

## Positioning

System-level, restrained, clear, and quietly technical. Borrow low-distraction principles from Typeless and material hierarchy from Apple while keeping ReadyType's own brand color, iconography, and Chinese-first voice.

## Themes

- Follow System is the default.
- Light uses a soft gray canvas, white content layers, dark text, and low-saturation green status color.
- Dark uses a near-system-black canvas, elevated charcoal content layers, and high-contrast text.
- Semantic tokens stay consistent across themes; views do not scatter hard-coded colors.

## HUD

- Target height: 56-64 pt with stable minimum and maximum width.
- Use native glass material where available and a translucent solid fallback.
- Combine one base stroke, one local highlight, and one state-driven light sweep.
- The sweep moves along the long edge rather than rotating around the border.
- Shadows separate the HUD from the active app without a large colored glow.

## Motion

| State | Motion |
| --- | --- |
| Entrance | 10-12 pt rise with a 160-200 ms fade |
| Listening | Voice-reactive waveform and slow edge highlight |
| Recognizing | Waveform settles; text crossfades in 120-160 ms |
| Polishing | Subtle edge-color change with stable layout |
| Complete | One green confirmation, then fade after about 900 ms |
| Copied | Amber feedback for about 1.5 seconds |
| Error | One restrained horizontal response, then stillness |

## Components and Accessibility

Use system typography and SF Symbols. Binary settings use switches, option sets use menus, and appearance uses a three-way segmented control. Cards stay at 8 pt radius or less and are not nested. Support keyboard navigation, VoiceOver labels, readable contrast, and Reduce Motion.
