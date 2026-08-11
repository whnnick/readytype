# ReadyType 1.6.0

ReadyType 1.6.0 focuses on understanding what the user is writing. It combines the current app, window, selected text, spoken instruction, and manual settings without adding a permanent interaction burden.

## Documents

- [Requirements](./REQUIREMENTS.md)
- [Interaction and Technical Architecture](./INTERACTION_ARCHITECTURE.md)
- [Implementation Plan](./PLAN.md)
- [Black-box Acceptance](./BLACK_BOX_TESTS.md)

## Core Scope

- With text selected, users can say commands such as “make this shorter,” “make it more natural,” “translate this into English,” or “reply to this.”
- A unified `Context Engine` resolves intent, app category, tone, and output language using an explicit priority order.
- Personal chat stays concise and natural; work chat stays direct; email, notes, documents, and AI tools use appropriate structure.
- ReadyType revalidates the target and selection before replacement. If the target changes, the original remains untouched and the result is copied instead of being written into the wrong window.
- Analytics include only anonymous action type, context category, outcome, and latency. Selected text, speech content, window titles, and app names are prohibited.

## Out of Scope

- Monitoring later edits or learning from them automatically.
- Silent Common Words insertion or full input history.
- Dual-engine live replacement, dialect expansion, cross-platform clients, or additional LLM providers.

Confirm-first correction learning remains a 1.7.0 candidate and must build on the 1.6.0 context and selection-safety foundation.
