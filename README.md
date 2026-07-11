# CodexUsageBar

[English](README.md) | [简体中文](README.zh-CN.md)

A lightweight, local, and focused macOS menu bar app for checking Codex usage at a glance.

## Core Idea

CodexUsageBar makes checking Codex usage as easy as checking your Mac battery.

The MVP displays the five-hour usage window directly in the menu bar:

```text
75% 16:57
```

- `75%`: Remaining usage in the five-hour Codex window.
- `16:57`: Reset time for the five-hour window.

Clicking the menu bar item shows both usage windows:

```text
Usage Remaining
5 hours    75%   16:57
1 week     97%   Jul 18
```

## MVP Scope

The first version includes:

- Codex support only.
- Five-hour remaining usage and reset time in the menu bar.
- Five-hour and weekly usage in the popover.
- Refresh status and clear failure states.
- Local data access through Codex app-server.

The first version intentionally excludes:

- Total token analytics.
- Token activity heatmaps.
- Plugin rankings.
- Skill usage analytics.
- Daily task dashboards.
- Claude Code support.
- Account switching.
- A full dashboard window.
- Cloud synchronization.
- Reading `~/.codex/auth.json`.
- Uploading usage data.

## Data Source

CodexUsageBar uses the local Codex app-server JSON-RPC protocol:

```text
codex app-server
account/rateLimits/read
```

The app only reads rate limit data and does not upload usage data.

## Current Status

The first runnable MVP is complete:

- The menu bar displays five-hour remaining usage and reset time.
- The percentage and reset time stay together as one fixed-size menu bar label, preventing the reset time from being compressed out of view.
- The popover displays five-hour and weekly usage.
- Usage refreshes at launch, when the popover opens, and every five minutes.
- Usage refreshes immediately after the Mac wakes from sleep.
- The last successful snapshot remains visible when a refresh fails.
- Snapshots older than ten minutes display a warning in the menu bar and popover.
- JSON-RPC response parsing is covered by tests.

Design documents:

- [MVP design specification](docs/superpowers/specs/2026-07-11-codex-usage-menu-bar-design.md)
- [MVP 设计文档](docs/superpowers/specs/2026-07-11-codex-usage-menu-bar-design.zh-CN.md)
- [Unnotarized preview release design](docs/superpowers/specs/2026-07-11-unnotarized-preview-release-design.md)
- [未公证预览版发布设计](docs/superpowers/specs/2026-07-11-unnotarized-preview-release-design.zh-CN.md)

## Download and Install

The `v0.1.0` download is an **unnotarized Apple Silicon preview** for macOS 14 or later. It is not signed with an Apple Developer ID and has not been notarized by Apple.

1. Open [GitHub Releases](https://github.com/ShaneD711/CodexUsageBar/releases) and download `CodexUsageBar-v0.1.0-macos-arm64.zip`.
2. Extract the ZIP and move `CodexUsageBar.app` to `/Applications`.
3. Try to open CodexUsageBar once.
4. Open `System Settings > Privacy & Security`, find the blocked CodexUsageBar message, and click `Open Anyway`.
5. Confirm the warning and enter your Mac password if requested.

Company- or school-managed Macs may prevent this override. A newly downloaded version may need to be approved again. See [Apple's guidance for opening an app from an unknown developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac) before deciding whether to continue.

### Verify the Download

Download the `.zip` and `.sha256` files into the same folder, then run:

```bash
shasum -a 256 -c CodexUsageBar-v0.1.0-macos-arm64.zip.sha256
```

Expected output:

```text
CodexUsageBar-v0.1.0-macos-arm64.zip: OK
```

### Uninstall

Quit CodexUsageBar and move `/Applications/CodexUsageBar.app` to the Trash. To also clear its last cached usage snapshot, run:

```bash
defaults delete com.shaned.CodexUsageBar
```

## Development Requirements

- macOS 14 or later.
- Xcode 16 or later.
- ChatGPT/Codex installed and signed in on the same Mac.

The project uses Swift, SwiftUI, and Swift Package Manager with no third-party dependencies.

## Run with Xcode

1. Open Xcode.
2. Select `File > Open`.
3. Open `Package.swift` from the project root.
4. Select the `CodexUsageBar` scheme and `My Mac` as the destination.
5. Click Run or press `Command + R`.

The app has no main window or Dock icon. After launch, find it in the macOS menu bar.

## Run from Terminal

Build, create a local `.app` bundle, and launch it:

```bash
./script/build_and_run.sh
```

Run tests:

```bash
swift test
```

The local app bundle is created at:

```text
dist/CodexUsageBar.app
```

## App Icon

The tracked icon assets are located at:

```text
Sources/CodexUsageBar/Resources/AppIcon.png
Sources/CodexUsageBar/Resources/AppIcon.icns
```

Regenerate both files from the code-defined design:

```bash
swift script/generate_app_icon.swift
```

The build script stops with a clear error when `AppIcon.icns` is missing, preventing a blank application icon from being packaged.

## Privacy

CodexUsageBar only requests rate limit data through the local `codex app-server`. It does not read `~/.codex/auth.json`, inspect conversation content, or upload usage data.

## License

CodexUsageBar is available under the [MIT License](LICENSE).

## Disclaimer

CodexUsageBar is an unofficial local utility and is not affiliated with OpenAI. It uses the local Codex app-server protocol, which may change in future Codex releases.
