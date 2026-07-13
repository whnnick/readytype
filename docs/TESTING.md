# Testing Guide

This guide is for first-time ReadyType testers.

## Install

1. Download `ReadyType.dmg` from Releases.
2. Open the DMG and drag `ReadyType.app` to Applications.
3. On first launch, if macOS says the developer cannot be verified, right-click `ReadyType.app`, choose `Open`, and confirm `Open`.

Do not disable macOS security settings.

## First Setup

1. Open ReadyType.
2. Add your own DeepSeek API key in Settings.
3. Grant microphone, speech recognition, and accessibility permissions.
4. If you want better long-form and terminology-heavy recognition, download the high-accuracy speech package in Settings.

Speech recognition itself does not require a separate cloud speech API key.

## How To Use

1. Put the cursor in any text field.
2. Double-press `Option` to start speaking.
3. Double-press `Option` again to finish and output.
4. Press `Esc` to cancel.

If automatic paste does not work, ReadyType copies the result to the clipboard. You can paste manually with `Command + V`.

## What To Test

- Input in WeChat, Notes, browsers, email clients, or document tools.
- Try direct dictation, polished writing, Chinese-to-English translation, and AI-ready instructions.
- Test short sentences, long sentences, mixed Chinese/English, names, project names, and technical terms.
- Test `Esc` cancellation and automatic paste.
- Compare recognition before and after the high-accuracy speech package is ready.

## Feedback

Please report feedback through GitHub Issues:

https://github.com/whnnick/readytype/issues

Useful details:

- ReadyType version
- macOS version
- App where you used ReadyType
- Output method
- What you said
- What ReadyType produced
- What you expected

Remove API keys, private chats, private emails, real customer information, and sensitive business content before posting.

## Maintainer Real-Voice Acceptance

- Fix the case count and stop conditions before testing; do not keep adding near-duplicate prompts during a run.
- Record only the scenario, spoken input, raw recognition, final output, timing, and paste result.
- Classify failures as recognition, Common Words/terminology, AI cleanup, language formatting, or delivery before changing code.
- Retest the failed case, one adjacent positive case, and one false-positive guard; the full release gate still runs before publishing.
