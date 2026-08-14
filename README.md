# DeepSeek Harness Desktop

<p align="center">
  <img src="Resources/AppIconSource.jpg" width="128" alt="DeepSeek Harness Desktop">
</p>

Native macOS desktop client for [DeepSeek Harness (dsh)](https://github.com/deepseek-ai/deepseek-harness) — a standalone `.app` that wraps the dsh Web UI in its own window, starts the local server for you, and keeps it running in the background.

> ⚠️ Not an official DeepSeek product. DeepSeek Harness itself is currently in developer preview.

## Download

Get the latest prebuilt app from the [Releases page](https://github.com/iMENGiCHAO/deepseek-harness-desktop/releases/latest):

- `DeepSeek-Harness-Desktop-1.0.0-macOS-universal.zip` — universal binary for Intel & Apple Silicon
- `DeepSeek-Harness-Desktop-1.0.0-macOS-universal.dmg` — drag-to-Applications disk image

The app is ad-hoc signed (no Apple Developer ID), so the first launch will be blocked by Gatekeeper. To open it: **right-click the app → Open → Open**, or run `xattr -dr com.apple.quarantine "DeepSeek Harness.app"`.

## Features

- Standalone macOS window embedding the dsh Web UI (`http://127.0.0.1:3080`)
- Auto-starts `dsh web` when the server isn't running; reuses an existing one when it is
- Finds `dsh` automatically: on `PATH`, in common install locations, or via `npx` on first run
- Menu bar: reload, open in browser, copy URL, login-item auto-start toggle
- Loading / error states with retry; logs written to `~/.dsh/dsh-desktop.log`

## Requirements

- macOS 13+
- Node.js 22+ (the app uses `dsh`, which is distributed via npm)
- A DeepSeek API key (or another supported provider)

Install `dsh` once (the app can also pull it via `npx` automatically):

```sh
npm i -g @deepseek-ai/dsh
```

## First run

1. Open the app.
2. In the window, go to **Settings → Models** and enter your DeepSeek API key.
3. Click **Choose workspace** and add your project directory.

Keys are stored locally in `~/.dsh` — nothing is uploaded to this repository or anywhere else.

## Build from source

```sh
./script/build_and_run.sh          # kill → build → package .app → launch
./script/build_and_run.sh release  # universal binary + zip + dmg (for publishing)
```

Outputs land in `dist/`. Requires the Swift toolchain (Xcode Command Line Tools).

## Privacy

This repository contains **no API keys, tokens, or credentials** — your model keys live only in `~/.dsh` on your own machine. The desktop app is a thin wrapper around the official open-source dsh runtime.

## License

MIT — see [LICENSE](LICENSE).
