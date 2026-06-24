<p align="center">
  <a href="./README.zh-CN.md">简体中文</a> | English
</p>

<h1 align="center">ReadyType</h1>

<p align="center">
  A Chinese-first macOS voice input tool for direct dictation, polished writing, English translation, and AI-ready instructions.
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-blue">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-6.0-orange">
  <img alt="Version" src="https://img.shields.io/badge/version-1.0.0-green">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-lightgrey">
</p>

## What It Does

ReadyType lets you double-press `Option`, speak naturally, and send the result to the current text field.

- `直接转文字`: direct dictation without calling DeepSeek.
- `整理成文`: turns messy speech into text that is easier to send or save.
- `翻译成英文`: turns spoken Chinese into natural English.
- `写给 AI`: turns spoken intent into a clear instruction for AI tools.
- `自动选择`: keeps short input fast and uses higher-accuracy local recognition when it is ready and useful.

## Download

Download the latest `ReadyType.dmg` from GitHub Releases.

This build is unsigned and not notarized. On first launch, macOS may show a warning that the developer cannot be verified. Open it from Applications by right-clicking `ReadyType.app`, choosing `Open`, and confirming `Open`.

Do not disable macOS security settings.

## Requirements

- macOS 14 or later
- Xcode command line tools for local builds
- A DeepSeek key for polished writing, translation, and AI-instruction output
- Microphone, speech recognition, and accessibility permissions

Speech recognition itself does not require a separate cloud speech API key.

## Use ReadyType

1. Open ReadyType.
2. Add your DeepSeek key in Settings. The key is stored in macOS Keychain.
3. Select an output method.
4. Put the cursor in any text field.
5. Double-press `Option` to start speaking.
6. Double-press `Option` again to finish and output.
7. Press `Esc` to cancel the current voice input.

If automatic paste is unavailable, ReadyType copies the result to the clipboard.

## Build From Source

Run tests:

```bash
swift test
```

Build the app:

```bash
./scripts/build-app.sh
```

Package a zip:

```bash
./scripts/package-app.sh
```

Package a DMG:

```bash
./scripts/package-dmg.sh
```

Generated files are written to `dist/`.

## Privacy

- DeepSeek keys are stored in macOS Keychain.
- Full transcript history is not stored.
- Direct dictation does not call DeepSeek.
- AI output methods send the current text to DeepSeek for processing.
- High-accuracy speech packages are stored under `~/Library/Application Support/ReadyType/Models/`.

## License

ReadyType is released under the MIT License. See [LICENSE](./LICENSE).
