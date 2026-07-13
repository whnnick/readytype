# ReadyType 1.4.0 Anonymous Event Specification

## Design Rules

- Every event and property uses a closed enum; business code cannot send free-form text.
- Record what happened, never what the user said.
- Durations, recording length, and system information use buckets to avoid high-cardinality data.
- Official build configuration and admin credentials stay out of the public repository; public source builds send nothing by default.

## Provider Metadata

Official builds use TelemetryDeck Swift SDK 2.14.1. In addition to the ReadyType properties below, the SDK attaches fixed compatibility metadata including app version and build, system version, architecture and Mac model, language/region/time zone, display properties, appearance, and accessibility preferences. ReadyType supplies no account, email, or other custom user identifier, and disables automatic SDK session events and session statistics.

Default metadata must be audited again before any SDK upgrade. Scope changes require this specification and the user-facing privacy disclosure to be updated first.

## Allowed Events

| Event | Allowed properties |
| --- | --- |
| `app_launched` | version, build, macOS major version, architecture |
| `onboarding_step` | step, result |
| `speech_package_action` | download/warm/update/delete, result, latency bucket |
| `voice_input_started` | recognition selection, output method |
| `voice_input_finished` | result, actual engine, output method, scenario category, recording bucket, latency bucket, delivery |
| `voice_input_cancelled` | stage |
| `voice_input_failed` | stage, fixed error code |
| `setting_changed` | setting name, enumerated value |

## Allowed Property Values

- Recognition selection: `automatic`, `fast`, `accurate`
- Actual engine: `apple`, `local`
- Output method: `direct`, `polished`, `translate`, `ai`
- Scenario category: `generic`, `chat`, `email`, `note`, `document`, `ai_tool`
- Delivery: `pasted`, `clipboard`, `failed`
- Recording bucket: `under_5s`, `5_15s`, `15_30s`, `over_30s`
- Latency bucket: `under_500ms`, `500_1500ms`, `1500_3000ms`, `over_3000ms`

New events or properties must update this specification and its tests before entering business code.
