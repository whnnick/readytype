# Troubleshooting

## macOS says the developer cannot be verified

ReadyType 1.0.0 is unsigned and not notarized.

1. Move `ReadyType.app` to Applications.
2. Right-click `ReadyType.app`.
3. Choose `Open`.
4. Confirm `Open` in the macOS dialog.

Do not disable macOS security settings.

## ReadyType opens, but the shortcut does not work

ReadyType uses double-press `Option` by default.

Check:

- ReadyType is running in the menu bar.
- You are double-pressing `Option`, not holding it down.
- ReadyType has Accessibility permission in `System Settings -> Privacy & Security -> Accessibility`.

If the shortcut works inside ReadyType but not in other apps, the missing permission is usually Accessibility.

## Recording does not start

Check:

- Microphone permission is enabled for ReadyType.
- Speech Recognition permission is enabled for ReadyType.
- Another app is not exclusively using the microphone.

You can review permissions in ReadyType's Permissions page and in macOS System Settings.

## Text is not pasted

ReadyType first tries to insert text into the current input field. If that fails, it copies the result to the clipboard.

Check:

- The cursor is inside a text field before you start speaking.
- ReadyType has Accessibility permission.
- If macOS asks whether ReadyType may control `System Events`, allow it.
- If no text appears, try `Command + V`; the result may already be copied.

Some apps handle text input differently, so clipboard fallback is expected in a few cases.

## DeepSeek output does not work

Direct dictation does not use DeepSeek. Polished writing, Chinese-to-English translation, and AI-instruction output do.

Check:

- Your DeepSeek key is saved in ReadyType Settings.
- The service address is reachable.
- The model name is valid for your DeepSeek account.
- Click `Test Connection` in Settings after changing the key, service address, or model.

ReadyType stores the key in macOS Keychain.

## High-accuracy speech package is not ready

Fast recognition still works when the high-accuracy speech package is missing or not ready.

The high-accuracy speech package:

- is useful for longer input, mixed Chinese/English, and terminology-heavy text;
- may need time to download and prepare;
- can be deleted and downloaded again from Settings;
- is stored under `~/Library/Application Support/ReadyType/Models/`.

If it is still preparing, continue using ReadyType normally. ReadyType will use fast recognition and switch to high-accuracy recognition when it is ready and useful.

## Recognition or output quality is wrong

Please report the issue through GitHub Issues:

https://github.com/whnnick/readytype/issues

Include:

- ReadyType version
- macOS version
- App where you used ReadyType
- Output method
- Recognition mode
- What you said
- What ReadyType produced
- What you expected

Remove API keys, private chats, private emails, and sensitive business content before posting.
