# High-Accuracy Speech Package Update Design

## Product Goal

Users should be able to distinguish whether the high-accuracy speech package is installed, ready for use, and aligned with the latest version verified by ReadyType. Checking or updating must not interrupt voice input.

## User-Visible States

Three state groups remain independent:

- Installation: not installed, downloading, installed, or failed.
- Readiness: not prepared, preparing, or ready.
- Update: not checked, checking, current recommended version, update available, or temporarily unable to check.

“Ready” only means the installed package is loaded. It does not mean the package is current. “Current recommended version” means the remote ReadyType manifest matches the installed version.

## Update Flow

1. The user selects Check for Updates and the app fetches a small JSON manifest from the public ReadyType repository.
2. The manifest can name only a ReadyType-verified official WhisperKit model variant, folder, version, and size. It cannot provide an arbitrary download URL.
3. When an update is available, the approximately 626 MiB download starts only after explicit user action.
4. The new package is downloaded to temporary storage and validated before it becomes current.
5. A failed download or validation keeps the previous package available.
6. The old package is removed only after the new package is prepared successfully. Users can still delete the package from Settings.

## Remote Manifest

The ReadyType repository maintains a deliberately small manifest:

```json
{
  "schemaVersion": 1,
  "recommendedModel": {
    "variant": "large-v3-v20240930_626MB",
    "folderName": "openai_whisper-large-v3-v20240930_626MB",
    "version": "2024-09-30",
    "sizeDescription": "about 626 MiB"
  }
}
```

The client rejects unknown schemas, empty fields, non-HTTPS sources, and model names outside the official WhisperKit naming convention. Network failures produce a temporary unable-to-check state rather than a false current-version result.

## Performance and Privacy

- A check downloads only a small JSON file. It does not load the model or block recording and launch.
- Model downloads continue through WhisperKit's official download path, not a ReadyType server.
- Requests do not upload transcripts, vocabulary, foreground app data, window titles, or DeepSeek credentials.
- The first phase supports manual checks only. Background checks require separate stability validation.

## Acceptance Criteria

- A matching remote manifest shows Current Recommended Version.
- A changed manifest shows the new version and size with a clear update action.
- Offline, timeout, invalid JSON, and unknown-schema cases show Temporarily Unable to Check.
- A failed update leaves the previous package usable.
- After a successful update, the installed version survives relaunch and prewarming still works.
