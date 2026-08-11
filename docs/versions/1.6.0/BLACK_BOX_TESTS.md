# ReadyType 1.6.0 Black-box Acceptance

## Current Status

Planning is complete and implementation has not started. This file is the release contract; implementation may update status and evidence but must not weaken acceptance targets.

| Requirement | Status | Release Evidence |
| --- | --- | --- |
| Single Context Engine | Not started | Priority, compatibility, and performance evidence pending. |
| Personal/work chat tone | Not started | Positive, negative, and real-app output pending. |
| Email, notes, documents, and AI-tool structure | Not started | No-invention and formatting evidence pending. |
| Spoken selected-text actions | Not started | Shorten, naturalize, translate, and reply pending. |
| Safe fallback after target changes | Not started | Selection, focus, and app-switch evidence pending. |
| Privacy and anonymous analytics | Not started | Allowlist and network inspection pending. |
| Automated and release gates | Not started | Tests, build, UI, sensitive scan, and artifacts pending. |

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

## Release Blockers

All P0 items remain unimplemented, so 1.6.0 is not releasable.
